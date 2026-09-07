import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' as dart_io;
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/models.dart';
import '../core/csv_parser.dart';
import '../services/local_store.dart';

class AppProvider extends ChangeNotifier {
  AppUser? user;
  List<Account> accounts = [];
  List<TransactionModel> transactions = [];
  List<CategoryModel> categories = [];
  bool loading = true;
  bool hasSeenOnboarding = false;
  CurrencyModel currency = CurrencyModel(code: 'USD', symbol: '\$', name: 'United States Dollar');
  DateTime currentDate = DateTime.now();


  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Auto-sync state
  bool _syncPending = false;
  bool get isSynced => !_syncPending;
  Timer? _syncDebounce;
  List<Map<String, dynamic>> _pendingDeltas = [];

  StreamSubscription? _connectivitySub;
  StreamSubscription? _authSub;

  AppProvider() {
    _init();
  }


  Future<void> _init() async {
    // Disable Firestore SDK disk cache — LocalStore owns all persistence.
    _db.settings = const Settings(persistenceEnabled: false);

    _syncPending = await LocalStore.getPendingSync();
    _pendingDeltas = await LocalStore.loadPendingDeltas();
    if (_pendingDeltas.isNotEmpty) {
      _syncPending = true;
    }
    await _loadCurrency();
    await _loadOnboardingStatus();

    // Listen to network status changes to automatically trigger pending syncs
    _connectivitySub = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      if (results.any((r) => r != ConnectivityResult.none)) {
        final pending = await LocalStore.getPendingSync();
        if ((pending || _pendingDeltas.isNotEmpty) && user != null) {
          debugPrint('[AppProvider] Internet restored — triggering automatic pending delta sync.');
          _scheduleSyncToCloud();
        }
      }
    });


    _authSub = _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final rawPhotoPath = prefs.getString('profile_photo_${firebaseUser.uid}');
        // Clear stale cached path if the file no longer exists on disk
        String? photoPath = rawPhotoPath;
        if (rawPhotoPath != null && !dart_io.File(rawPhotoPath).existsSync()) {
          await prefs.remove('profile_photo_${firebaseUser.uid}');
          photoPath = null;
        }
        final name = prefs.getString('profile_name_${firebaseUser.uid}');
        user = AppUser(uid: firebaseUser.uid, email: firebaseUser.email ?? '', photoPath: photoPath, name: name);
        // Restore photo from Firestore if not present locally
        if (photoPath == null) {
          _restorePhotoFromFirestore(firebaseUser.uid);
        }
        await _fetchUserData();
      } else {
        user = null;
        accounts = [];
        transactions = [];
        categories = [];
        _pendingDeltas = [];
        loading = false;
        notifyListeners();
      }
    });
  }


  @override
  void dispose() {
    _connectivitySub?.cancel();
    _authSub?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load onboarding status: \$e');
    }
  }

  Future<void> completeOnboarding() async {
    hasSeenOnboarding = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_seen_onboarding', true);
    } catch (e) {
      debugPrint('Failed to save onboarding status: \$e');
    }
  }

  Future<void> _loadCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCurrency = prefs.getString('user_currency');
      if (savedCurrency != null) {
        final decoded = CurrencyModel.fromMap(json.decode(savedCurrency));

        // Auto-fix corrupted symbols cached from a previous encoding issue
        const fixedSymbols = {
          'INR': '₹',
          'GBP': '£',
          'EUR': '€',
          'JPY': '¥',
          'AED': 'د.إ',
        };
        final correctedSymbol = fixedSymbols[decoded.code] ?? decoded.symbol;

        currency = CurrencyModel(
          code: decoded.code,
          symbol: correctedSymbol,
          name: decoded.name,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load currency: \$e');
    }
  }

  Future<void> updateCurrency(CurrencyModel newCurrency) async {
    currency = newCurrency;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_currency', json.encode(newCurrency.toMap()));
      
      if (user != null) {
        await _db.collection('users').doc(user!.uid).set({
          'currency': newCurrency.toMap(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to save currency: $e');
    }
  }

  void setCurrentDate(DateTime date) {
    currentDate = date;
    notifyListeners();
  }


  Future<void> refreshData() async {
    await _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;

    // 1. Load local cache immediately in parallel — UI renders with no network wait.
    final results = await Future.wait([
      LocalStore.loadAccounts(),
      LocalStore.loadTransactions(),
      LocalStore.loadCategories(),
    ]);
    final localAccounts = results[0] as List<Account>;
    final localTransactions = results[1] as List<TransactionModel>;
    final localCategories = results[2] as List<CategoryModel>;
    
    final hasCachedData = localAccounts.isNotEmpty ||
        localTransactions.isNotEmpty ||
        localCategories.isNotEmpty;

    if (hasCachedData) {
      accounts = localAccounts;
      transactions = localTransactions;
      categories = localCategories;
      _sortAccounts();
      loading = false;
      notifyListeners();
    } else {
      loading = true;
      notifyListeners();
      // If there is no local data (e.g., fresh login or install), automatically attempt to restore from cloud.
      try {
        await _restoreFromCloud();
      } catch (e) {
        debugPrint('Auto-restore failed: $e');
        // If it fails (e.g. offline), we stop loading so UI isn't stuck.
        loading = false;
        notifyListeners();
      }
    }
  }

  /// Pull data from Firestore to populate local state/cache on fresh startup or login.
  Future<void> _restoreFromCloud() async {
    if (user == null) return;
    loading = true;
    notifyListeners();
    try {
      final uid = user!.uid;
      final accountsRef = _db.collection('users').doc(uid).collection('accounts');
      final transRef = _db.collection('users').doc(uid).collection('transactions');
      final categoriesRef = _db.collection('users').doc(uid).collection('categories');

      // Pull user currency preference.
      final userDoc = await _db.collection('users').doc(uid).get().timeout(const Duration(seconds: 15));
      if (userDoc.exists && userDoc.data() != null && userDoc.data()!.containsKey('currency')) {
        final decoded = CurrencyModel.fromMap(userDoc.data()!['currency']);
        const fixedSymbols = {
          'INR': '₹', 'GBP': '£', 'EUR': '€', 'JPY': '¥', 'AED': 'د.إ',
        };
        final correctedSymbol = fixedSymbols[decoded.code] ?? decoded.symbol;
        currency = CurrencyModel(code: decoded.code, symbol: correctedSymbol, name: decoded.name);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_currency', json.encode(currency.toMap()));
      }

      final accountsSnap = await accountsRef.get().timeout(const Duration(seconds: 15));
      final results = await Future.wait([
        transRef.orderBy('date', descending: true).limit(2000).get(),
        categoriesRef.get(),
      ]).timeout(const Duration(seconds: 15));
      final transSnap = results[0];
      final catSnap   = results[1];

      accounts     = accountsSnap.docs.map((d) => Account.fromMap(d.id, d.data())).toList();
      transactions = transSnap.docs.map((d) => TransactionModel.fromMap(d.id, d.data())).toList();
      categories   = catSnap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList();

      _sortAccounts();
      loading = false;
      await _saveAllToLocal();
      await LocalStore.setLastSyncedAt(DateTime.now());
      notifyListeners();
    } catch (e) {
      debugPrint('[AppProvider] Firestore restore error: $e');
      loading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Explicitly syncs local state with Firestore online.
  Future<void> syncOnline() async {
    if (user == null) return;
    try {
      final result = await Connectivity().checkConnectivity();
      if (result.contains(ConnectivityResult.none)) {
        throw Exception('No internet connection available.');
      }
    } catch (e) {
      if (e.toString().contains('internet connection')) rethrow;
    }

    _syncPending = true;
    notifyListeners();
    try {
      if (_pendingDeltas.isNotEmpty) {
        await _flushDeltasToFirestore();
      } else {
        await _pushToFirestore();
      }
      if (_syncPending) {
        throw Exception('Cloud sync could not be completed.');
      }
    } catch (e) {
      _syncPending = true;
      notifyListeners();
      rethrow;
    }
  }

  void _enqueueDelta(String collection, String id, String op, Map<String, dynamic>? data) {
    _pendingDeltas.removeWhere((d) => d['collection'] == collection && d['id'] == id);
    _pendingDeltas.add({
      'collection': collection,
      'id': id,
      'op': op,
      'data': ?data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    _syncPending = true;
    LocalStore.setPendingSync(true);
    LocalStore.savePendingDeltas(_pendingDeltas);
  }

  /// Schedules an automatic background sync of pending deltas to Firestore.
  /// Debounced so rapid mutations are batched into a single upload.
  void _scheduleSyncToCloud() {
    if (user == null) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 600), () async {
      if (user == null) return;
      try {
        final result = await Connectivity().checkConnectivity();
        if (result.contains(ConnectivityResult.none)) {
          debugPrint('[AppProvider] Offline — delta sync deferred, marking sync pending.');
          _syncPending = true;
          await LocalStore.setPendingSync(true);
          notifyListeners();
          return;
        }
        try {
          if (_pendingDeltas.isNotEmpty) {
            await _flushDeltasToFirestore();
          } else if (_syncPending) {
            await _pushToFirestore();
          }
        } catch (e) {
          debugPrint('[AppProvider] Background delta sync failed: $e');
          _syncPending = true;
          await LocalStore.setPendingSync(true);
          notifyListeners();
        }
      } catch (e) {
        if (e.toString().contains('internet connection')) {
          _syncPending = true;
          await LocalStore.setPendingSync(true);
          notifyListeners();
        }
      }
    });
  }

  /// Flushes queued delta mutations (document sets & deletes) to Firestore in a minimal batch.
  Future<void> _flushDeltasToFirestore() async {
    if (user == null) return;
    if (_pendingDeltas.isEmpty) {
      _syncPending = false;
      await LocalStore.setPendingSync(false);
      notifyListeners();
      return;
    }

    try {
      final uid = user!.uid;
      final deltasToFlush = List<Map<String, dynamic>>.from(_pendingDeltas);
      WriteBatch batch = _db.batch();
      int ops = 0;

      Future<void> flushBatch() async {
        if (ops > 0) {
          await batch.commit();
          batch = _db.batch();
          ops = 0;
        }
      }

      for (final delta in deltasToFlush) {
        final col = delta['collection'] as String;
        final docId = delta['id'] as String;
        final op = delta['op'] as String;
        final docRef = _db.collection('users').doc(uid).collection(col).doc(docId);

        if (op == 'delete') {
          batch.delete(docRef);
        } else {
          final data = Map<String, dynamic>.from(delta['data'] as Map);
          batch.set(docRef, data, SetOptions(merge: true));
        }
        if (++ops >= 450) {
          await flushBatch();
        }
      }
      await flushBatch();

      // Remove successfully flushed deltas
      _pendingDeltas.removeWhere((d) => deltasToFlush.contains(d));
      await LocalStore.savePendingDeltas(_pendingDeltas);
      await LocalStore.setLastSyncedAt(DateTime.now());
      _syncPending = _pendingDeltas.isNotEmpty;
      await LocalStore.setPendingSync(_syncPending);
      notifyListeners();
      debugPrint('[AppProvider] Successfully flushed ${deltasToFlush.length} delta(s) to Firestore.');
    } catch (e) {
      _syncPending = true;
      await LocalStore.setPendingSync(true);
      notifyListeners();
      debugPrint('[AppProvider] Error flushing deltas to Firestore: $e');
      rethrow;
    }
  }

  /// Fallback: Pushes full in-memory state to Firestore (e.g. manual full backup).
  Future<void> _pushToFirestore() async {
    if (user == null) return;
    try {
      final uid = user!.uid;
      final accountsRef   = _db.collection('users').doc(uid).collection('accounts');
      final transRef      = _db.collection('users').doc(uid).collection('transactions');
      final categoriesRef = _db.collection('users').doc(uid).collection('categories');

      WriteBatch batch = _db.batch();
      int ops = 0;

      Future<void> flush() async {
        if (ops > 0) { await batch.commit(); batch = _db.batch(); ops = 0; }
      }

      for (final a in accounts) {
        batch.set(accountsRef.doc(a.id), a.toMap());
        if (++ops >= 450) await flush();
      }
      for (final t in transactions) {
        batch.set(transRef.doc(t.id), t.toMap());
        if (++ops >= 450) await flush();
      }
      for (final c in categories) {
        batch.set(categoriesRef.doc(c.id), c.toMap());
        if (++ops >= 450) await flush();
      }
      await flush();
      _pendingDeltas.clear();
      await LocalStore.savePendingDeltas([]);
      await LocalStore.setLastSyncedAt(DateTime.now());
      await LocalStore.setPendingSync(false);
      _syncPending = false;
      notifyListeners();
      debugPrint('[AppProvider] Full push to Firestore successful.');
    } catch (e) {
      _syncPending = true;
      await LocalStore.setPendingSync(true);
      notifyListeners();
      debugPrint('[AppProvider] Full push error: $e');
    }
  }

  void _sortAccounts() {
    accounts.sort((a, b) {
      final cmp = a.position.compareTo(b.position);
      return cmp != 0 ? cmp : a.createdAt.compareTo(b.createdAt);
    });
  }

  Future<void> _saveAllToLocal() async {
    await Future.wait([
      LocalStore.saveAccounts(accounts),
      LocalStore.saveTransactions(transactions),
      LocalStore.saveCategories(categories),
    ]);
  }

  Future<void> _saveTransactionsAndAccounts() async {
    await Future.wait([
      LocalStore.saveAccounts(accounts),
      LocalStore.saveTransactions(transactions),
    ]);
  }

  Future<void> updateAccountsOrder(List<Account> reorderedList) async {
    if (user == null) return;
    // Update in-memory immediately.
    accounts = List.from(reorderedList);
    for (int i = 0; i < accounts.length; i++) {
      final a = accounts[i];
      accounts[i] = Account(id: a.id, name: a.name, balance: a.balance, createdAt: a.createdAt, position: i);
      _enqueueDelta('accounts', a.id, 'set', accounts[i].toMap());
    }
    notifyListeners();
    await LocalStore.saveAccounts(accounts);
    _scheduleSyncToCloud();
  }

  // ── Helper: compute account balance delta in-memory ────────────────────
  void _applyTransactionToAccounts(TransactionModel tx, {bool reverse = false}) {
    final sign = reverse ? -1.0 : 1.0;
    accounts = accounts.map((a) {
      if (tx.type == 'transfer') {
        if (a.id == tx.accountId) {
          return Account(id: a.id, name: a.name, balance: a.balance - sign * tx.amount, createdAt: a.createdAt, position: a.position);
        }
        if (a.id == tx.toAccountId) {
          return Account(id: a.id, name: a.name, balance: a.balance + sign * tx.amount, createdAt: a.createdAt, position: a.position);
        }
      } else if (a.id == tx.accountId) {
        final delta = tx.type == 'income' ? sign * tx.amount : -sign * tx.amount;
        return Account(id: a.id, name: a.name, balance: a.balance + delta, createdAt: a.createdAt, position: a.position);
      }
      return a;
    }).toList();
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    if (user == null) return;
    // Generate a local ID (Firestore doc ID format).
    final localId = _db.collection('_').doc().id;
    final tx = TransactionModel(
      id: localId,
      amount: transaction.amount,
      type: transaction.type,
      categoryId: transaction.categoryId,
      accountId: transaction.accountId,
      toAccountId: transaction.toAccountId,
      note: transaction.note,
      date: transaction.date,
    );
    // Update in-memory.
    transactions = [tx, ...transactions];
    _applyTransactionToAccounts(tx);
    notifyListeners();
    // Persist locally, then sync delta to cloud.
    await _saveTransactionsAndAccounts();
    _enqueueDelta('transactions', tx.id, 'set', tx.toMap());
    for (final a in accounts) {
      if (a.id == tx.accountId || (tx.type == 'transfer' && a.id == tx.toAccountId)) {
        _enqueueDelta('accounts', a.id, 'set', a.toMap());
      }
    }
    _scheduleSyncToCloud();
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    if (user == null) return;
    // Update in-memory.
    transactions = transactions.where((t) => t.id != transaction.id).toList();
    _applyTransactionToAccounts(transaction, reverse: true);
    notifyListeners();
    // Persist locally, then sync delta to cloud.
    await _saveTransactionsAndAccounts();
    _enqueueDelta('transactions', transaction.id, 'delete', null);
    for (final a in accounts) {
      if (a.id == transaction.accountId || (transaction.type == 'transfer' && a.id == transaction.toAccountId)) {
        _enqueueDelta('accounts', a.id, 'set', a.toMap());
      }
    }
    _scheduleSyncToCloud();
  }

  Future<void> updateTransaction(TransactionModel oldTx, TransactionModel newTx) async {
    if (user == null) return;
    // Reverse old, apply new in-memory.
    _applyTransactionToAccounts(oldTx, reverse: true);
    _applyTransactionToAccounts(newTx);
    transactions = transactions.map((t) => t.id == oldTx.id ? newTx : t).toList();
    notifyListeners();
    // Persist locally, then sync delta to cloud.
    await _saveTransactionsAndAccounts();
    _enqueueDelta('transactions', newTx.id, 'set', newTx.toMap());
    for (final a in accounts) {
      if (a.id == newTx.accountId || a.id == oldTx.accountId ||
          (newTx.type == 'transfer' && a.id == newTx.toAccountId) ||
          (oldTx.type == 'transfer' && a.id == oldTx.toAccountId)) {
        _enqueueDelta('accounts', a.id, 'set', a.toMap());
      }
    }
    _scheduleSyncToCloud();
  }

  Future<void> addAccount(String name, double balance) async {
    if (user == null) return;
    final id = _db.collection('_').doc().id;
    final now = DateTime.now().millisecondsSinceEpoch;
    final acc = Account(id: id, name: name, balance: balance, createdAt: now, position: accounts.length);
    accounts = [...accounts, acc];
    notifyListeners();
    await LocalStore.saveAccounts(accounts);
    _enqueueDelta('accounts', acc.id, 'set', acc.toMap());
    _scheduleSyncToCloud();
  }

  Future<void> updateAccount(String id, String name, double balance) async {
    if (user == null) return;
    accounts = accounts.map((a) => a.id == id
        ? Account(id: a.id, name: name, balance: balance, createdAt: a.createdAt, position: a.position)
        : a).toList();
    notifyListeners();
    await LocalStore.saveAccounts(accounts);
    final acc = accounts.firstWhere((a) => a.id == id);
    _enqueueDelta('accounts', acc.id, 'set', acc.toMap());
    _scheduleSyncToCloud();
  }

  Future<void> deleteAccount(String id) async {
    if (user == null) return;
    accounts = accounts.where((a) => a.id != id).toList();
    notifyListeners();
    await LocalStore.saveAccounts(accounts);
    _enqueueDelta('accounts', id, 'delete', null);
    _scheduleSyncToCloud();
  }

  Future<void> addCategory(String name, String icon, String type) async {
    if (user == null) return;
    final id = _db.collection('_').doc().id;
    final cat = CategoryModel(id: id, name: name, icon: icon, type: type);
    categories = [...categories, cat];
    notifyListeners();
    await LocalStore.saveCategories(categories);
    _enqueueDelta('categories', cat.id, 'set', cat.toMap());
    _scheduleSyncToCloud();
  }

  Future<void> updateCategory(String id, String name, String icon, String type) async {
    if (user == null) return;
    categories = categories.map((c) => c.id == id
        ? CategoryModel(id: c.id, name: name, icon: icon, type: type)
        : c).toList();
    notifyListeners();
    await LocalStore.saveCategories(categories);
    final cat = categories.firstWhere((c) => c.id == id);
    _enqueueDelta('categories', cat.id, 'set', cat.toMap());
    _scheduleSyncToCloud();
  }

  Future<void> deleteCategory(String id) async {
    if (user == null) return;
    categories = categories.where((c) => c.id != id).toList();
    notifyListeners();
    await LocalStore.saveCategories(categories);
    _enqueueDelta('categories', id, 'delete', null);
    _scheduleSyncToCloud();
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      loading = true;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Email Sign-In Error: $e");
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmailAndPassword(String email, String password) async {
    try {
      loading = true;
      notifyListeners();
      await _auth.createUserWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      debugPrint("Email Sign-Up Error: $e");
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }



  Future<void> exportTransactionsCSV({DateTime? startDate, DateTime? endDate}) async {
    if (user == null) return;
    
    List<List<dynamic>> rows = [];
    rows.add(['TIME', 'TYPE', 'AMOUNT', 'CATEGORY', 'ACCOUNT', 'TO ACCOUNT', 'NOTES']);
    
    final DateFormat formatter = DateFormat('MMM dd, yyyy');
    
    final filteredTransactions = transactions.where((tx) {
      if (startDate == null && endDate == null) return true;
      final date = DateTime.fromMillisecondsSinceEpoch(tx.date);
      // We set the end date to the end of the selected day to include all transactions on that day
      final endOfDay = endDate != null ? DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999) : null;
      if (startDate != null && date.isBefore(startDate)) return false;
      if (endOfDay != null && date.isAfter(endOfDay)) return false;
      return true;
    }).toList();

    int count = 0;
    final Map<String, CategoryModel> categoryMap = { for (var c in categories) c.id : c };
    final Map<String, Account> accountMap = { for (var a in accounts) a.id : a };

    for (var tx in filteredTransactions) {
      if (++count % 50 == 0) await Future.delayed(const Duration(milliseconds: 1));
      String catName = (categoryMap[tx.categoryId] ?? CategoryModel(id: '', name: 'Unknown', icon: '', type: tx.type)).name;
      String accName = (accountMap[tx.accountId] ?? Account(id: '', name: 'Unknown', balance: 0, createdAt: 0)).name;
      
      String toAccName = '';
      if (tx.type == 'transfer' && tx.toAccountId.isNotEmpty) {
        toAccName = accountMap[tx.toAccountId]?.name ?? '';
      }
      
      String typeLabel = tx.type == 'income' ? '(+) Income' : (tx.type == 'transfer' ? '(~) Transfer' : '(-) Expense');
      
      rows.add([
        formatter.format(DateTime.fromMillisecondsSinceEpoch(tx.date)),
        typeLabel,
        tx.amount,
        catName,
        accName,
        toAccName,
        tx.note
      ]);
    }
    
    String csv = Csv().encode(rows);
    
    final directory = await getApplicationDocumentsDirectory();
    final path = "${directory.path}/transactions.csv";
    final file = dart_io.File(path);
    await file.writeAsString(csv);
    
    await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'My Transactions'));
  }

  Future<int> importTransactionsCSV({
    Future<bool?> Function()? onStartImport,
    void Function(int current, int total)? onProgress,
  }) async {
    if (user == null) return 0;
    
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    
    if (result != null && result.files.single.path != null) {
      bool overwrite = false;
      if (onStartImport != null) {
        final res = await onStartImport();
        if (res == null) return -1; // cancelled
        overwrite = res;
      }
      
      final file = dart_io.File(result.files.single.path!);
      
      // Read bytes and decode
      final bytes = await file.readAsBytes();
      
      final rows = await compute(_parseCsvInBackground, bytes);
      
      if (rows.isEmpty) throw Exception("The selected CSV file is empty.");
      
      // Dynamically identify header row and data start index
      int headerIndex = -1;
      int dataStartIndex = 0;
      
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        if (row.length >= 3) {
          final rowStr = row.join().toUpperCase();
          if (rowStr.contains('TIME') || rowStr.contains('TYPE') || rowStr.contains('AMOUNT') || rowStr.contains('CATEGORY')) {
            headerIndex = i;
            dataStartIndex = i + 1;
            break;
          } else {
            dataStartIndex = i;
            break;
          }
        }
      }
      
      // Map headers to column indices
      int timeIdx = -1;
      int typeIdx = -1;
      int amountIdx = -1;
      int catIdx = -1;
      int accIdx = -1;
      int toAccIdx = -1;
      int notesIdx = -1;
      
      if (headerIndex != -1) {
        final headerRow = rows[headerIndex].map((e) => e.toString().trim().toUpperCase()).toList();
        for (int i = 0; i < headerRow.length; i++) {
          final col = headerRow[i];
          if (col == 'TIME' || col == 'DATE' || col == 'WHEN') {
            timeIdx = i;
          } else if (col == 'TYPE' || col == 'TRANSACTION TYPE') {
            typeIdx = i;
          } else if (col == 'AMOUNT' || col == 'VALUE' || col == 'COST') {
            amountIdx = i;
          } else if (col == 'CATEGORY' || col == 'TAG') {
            catIdx = i;
          } else if (col == 'ACCOUNT' || col == 'SOURCE' || col == 'WALLET') {
            accIdx = i;
          } else if (col == 'TO ACCOUNT' || col == 'DESTINATION') {
            toAccIdx = i;
          } else if (col == 'NOTES' || col == 'NOTE' || col == 'MEMO' || col == 'DESCRIPTION' || col == 'COMMENT') {
            notesIdx = i;
          }
        }
      }
      
      // Default fallbacks if indices were not mapped
      if (timeIdx == -1) timeIdx = 0;
      if (typeIdx == -1) typeIdx = 1;
      if (amountIdx == -1) amountIdx = 2;
      if (catIdx == -1) catIdx = 3;
      if (accIdx == -1) accIdx = 4;
      if (toAccIdx == -1 && rows.isNotEmpty && rows.first.length > 5 && rows.first[5].toString().toUpperCase() == 'TO ACCOUNT') {
        toAccIdx = 5;
      }
      if (notesIdx == -1) notesIdx = toAccIdx != -1 ? 6 : 5;

      final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
      final categoriesRef = _db.collection('users').doc(user!.uid).collection('categories');

      if (overwrite) {
        final transRef = _db.collection('users').doc(user!.uid).collection('transactions');
        WriteBatch delBatch = _db.batch();
        int delCount = 0;
        
        Future<void> addToDelBatch(List<QueryDocumentSnapshot> docs) async {
           for (var doc in docs) {
              delBatch.delete(doc.reference);
              delCount++;
              if (delCount >= 400) {
                 await delBatch.commit();
                 delBatch = _db.batch();
                 delCount = 0;
              }
           }
        }
        
        await addToDelBatch((await transRef.get()).docs);
        await addToDelBatch((await accountsRef.get()).docs);
        await addToDelBatch((await categoriesRef.get()).docs);
        if (delCount > 0) await delBatch.commit();
        
        transactions.clear();
        accounts.clear();
        categories.clear();
        notifyListeners();
        

      }
      
      int importedCount = 0;
      final totalToImport = rows.length - dataStartIndex;
      if (onProgress != null) {
        onProgress(0, totalToImport);
      }

      WriteBatch currentBatch = _db.batch();
      int operationCount = 0;
      Map<String, double> accountBalanceUpdates = {};
      final transColRef = _db.collection('users').doc(user!.uid).collection('transactions');

      final Map<String, Account> accountNameMap = {
        for (final a in accounts) a.name.toLowerCase(): a,
      };
      final Map<String, CategoryModel> categoryNameMap = {
        for (final c in categories) c.name.toLowerCase(): c,
      };

      for (int i = dataStartIndex; i < rows.length; i++) {
        var row = rows[i];
        if (row.length < 3) {
          if (onProgress != null) {
            onProgress(importedCount, totalToImport);
          }
          continue;
        }
        
        // Ensure required indices are within bounds
        final maxReqIdx = [timeIdx, typeIdx, amountIdx].reduce((a, b) => a > b ? a : b);
        if (row.length <= maxReqIdx) {
          if (onProgress != null) {
            onProgress(importedCount, totalToImport);
          }
          continue;
        }
        
        String timeStr = row[timeIdx].toString().trim();
        String typeStr = row[typeIdx].toString().trim();
        final parsed = double.tryParse(row[amountIdx].toString().replaceAll(RegExp(r'[^0-9.]'), ''));
        if (parsed == null || parsed <= 0) continue;
        final double amount = parsed;
        
        String categoryName = (catIdx != -1 && row.length > catIdx && row[catIdx].toString().trim().isNotEmpty) ? row[catIdx].toString().trim() : 'Uncategorized';
        String accRaw = (accIdx != -1 && row.length > accIdx) ? row[accIdx].toString().trim() : '';
        String accountName = accRaw.isNotEmpty ? accRaw : 'Bank';
        String notes = (notesIdx != -1 && row.length > notesIdx) ? row[notesIdx].toString().trim() : '';
        
        DateTime dt;
        try {
          final formats = [
            'MMM dd, yyyy',
            'MMM dd, yy',
            'MM/dd/yyyy',
            'dd/MM/yyyy',
            'yyyy-MM-dd',
            'dd-MMM-yyyy',
            'dd MMM yyyy',
          ];
          DateTime? parsedDate;
          for (var format in formats) {
            try {
              parsedDate = DateFormat(format).parse(timeStr);
              if (parsedDate.year < 100) {
                parsedDate = DateTime(
                  parsedDate.year + 2000,
                  parsedDate.month,
                  parsedDate.day,
                  parsedDate.hour,
                  parsedDate.minute,
                );
              }
              break;
            } catch (_) {}
          }
          dt = parsedDate ?? DateTime.now();
        } catch (_) {
          dt = DateTime.now();
        }
        
        String type;
        if (typeStr.toLowerCase().contains('transfer')) {
          type = 'transfer';
        } else if (typeStr.toLowerCase().contains('income')) {
          type = 'income';
        } else {
          type = 'expense';
        }
        
        String toAccountName = '';
        if (type == 'transfer') {
          if (toAccIdx != -1 && row.length > toAccIdx) {
            toAccountName = row[toAccIdx].toString().trim();
          }
          if (toAccountName.isEmpty && accountName.contains('->')) {
            final parts = accountName.split('->');
            accountName = parts[0].trim();
            if (parts.length > 1) {
              toAccountName = parts[1].trim();
            }
          }
        }
        
        // Find or create source account
        final accKey = accountName.toLowerCase();
        Account? acc = accountNameMap[accKey];
        String accId;
        if (acc == null) {
          final doc = accountsRef.doc();
          accId = doc.id;
          acc = Account(id: accId, name: accountName, balance: 0, createdAt: DateTime.now().millisecondsSinceEpoch);
          accounts.add(acc);
          accountNameMap[accKey] = acc;
          currentBatch.set(doc, acc.toMap());
          operationCount++;
        } else {
          accId = acc.id;
        }

        // Handle target account for transfers
        String toAccId = '';
        if (type == 'transfer' && toAccountName.isNotEmpty) {
          final toAccKey = toAccountName.toLowerCase();
          Account? toAcc = accountNameMap[toAccKey];
          if (toAcc == null) {
            final doc = accountsRef.doc();
            toAccId = doc.id;
            toAcc = Account(id: toAccId, name: toAccountName, balance: 0, createdAt: DateTime.now().millisecondsSinceEpoch);
            accounts.add(toAcc);
            accountNameMap[toAccKey] = toAcc;
            currentBatch.set(doc, toAcc.toMap());
            operationCount++;
          } else {
            toAccId = toAcc.id;
          }
        }

        // Find or create category
        final catKey = categoryName.toLowerCase();
        CategoryModel? cat = categoryNameMap[catKey];
        String catId;
        if (cat == null) {
          final icon = _getIconForCategory(categoryName);
          final doc = categoriesRef.doc();
          catId = doc.id;
          cat = CategoryModel(id: catId, name: categoryName, icon: icon, type: type);
          categories.add(cat);
          categoryNameMap[catKey] = cat;
          currentBatch.set(doc, cat.toMap());
          operationCount++;
        } else {
          catId = cat.id;
        }
        
        // Add transaction to batch
        final txDoc = transColRef.doc();
        final newTx = TransactionModel(
          id: txDoc.id,
          amount: amount,
          type: type,
          categoryId: catId,
          accountId: accId,
          toAccountId: toAccId,
          note: notes,
          date: dt.millisecondsSinceEpoch,
        );
        
        currentBatch.set(txDoc, newTx.toMap());
        operationCount++;
        
        // Accumulate balance changes locally
        double currentBalance = accountBalanceUpdates[accId] ?? acc.balance;
        if (type == 'income') {
          currentBalance += amount;
        } else if (type == 'expense') {
          currentBalance -= amount;
        } else if (type == 'transfer') {
          currentBalance -= amount; // Deduct from source
          if (toAccId.isNotEmpty) {
             Account? toAcc = accounts.cast<Account?>().firstWhere((a) => a?.id == toAccId, orElse: () => null);
             if (toAcc != null) {
               double toBalance = accountBalanceUpdates[toAccId] ?? toAcc.balance;
               toBalance += amount; // Add to target
               accountBalanceUpdates[toAccId] = toBalance;
             }
          }
        }
        accountBalanceUpdates[accId] = currentBalance;
        
        if (operationCount >= 400) {
          await currentBatch.commit();
          currentBatch = _db.batch();
          operationCount = 0;
        }

        importedCount++;
        if (onProgress != null) {
          onProgress(importedCount, totalToImport);
        }
      }
      
      // Update the accumulated balances to the batch
      for (var entry in accountBalanceUpdates.entries) {
        currentBatch.update(accountsRef.doc(entry.key), {'balance': entry.value});
        
        operationCount++;
        if (operationCount >= 400) {
          await currentBatch.commit();
          currentBatch = _db.batch();
          operationCount = 0;
        }
      }
      
      if (operationCount > 0) {
        await currentBatch.commit();
      }
      
      if (importedCount == 0) {
        throw Exception("Format is incorrect. No valid transactions found in the CSV file. Make sure it contains Time, Type, Amount, Category, Account, and Notes.");
      }
      
      return importedCount;
    }
    return -1;
  }


  Future<void> clearAllData() async {
    if (user == null) return;
    
    loading = true;
    notifyListeners();

    try {
      final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
      final transRef = _db.collection('users').doc(user!.uid).collection('transactions');
      final categoriesRef = _db.collection('users').doc(user!.uid).collection('categories');

      WriteBatch delBatch = _db.batch();
      int delCount = 0;
      
      Future<void> addToDelBatch(List<QueryDocumentSnapshot> docs) async {
         for (var doc in docs) {
            delBatch.delete(doc.reference);
            delCount++;
            if (delCount >= 400) {
               await delBatch.commit();
               delBatch = _db.batch();
               delCount = 0;
            }
         }
      }

      await addToDelBatch((await accountsRef.get()).docs);
      await addToDelBatch((await transRef.get()).docs);
      await addToDelBatch((await categoriesRef.get()).docs);
      if (delCount > 0) await delBatch.commit();

      // Clear local storage as well
      await LocalStore.clearAll();
      accounts = [];
      transactions = [];
      categories = [];
    } catch (e) {
      debugPrint("Error clearing data: $e");
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      loading = true;
      notifyListeners();
      // Cancel any pending debounce and force an immediate sync before logging out.
      _syncDebounce?.cancel();
      _syncDebounce = null;
      if (user != null) {
        try {
          await _pushToFirestore();
          debugPrint('[AppProvider] Pre-logout sync completed.');
        } catch (e) {
          debugPrint('[AppProvider] Pre-logout sync failed (continuing logout): $e');
        }
      }
    } finally {
      loading = false;
      // Clear local cache so the next user starts fresh.
      await LocalStore.clearAll();
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint('Google Sign-Out Error: $e');
      }
      await _auth.signOut();
    }
  }
  
  String _getIconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant')) return '🍔';
    if (lower.contains('transport') || lower.contains('bus') || lower.contains('car') || lower.contains('taxi')) return '🚌';
    if (lower.contains('subscript') || lower.contains('netflix')) return '🔄';
    if (lower.contains('print') || lower.contains('office') || lower.contains('stationery')) return '🖨️';
    if (lower.contains('reward') || lower.contains('bonus') || lower.contains('grant')) return '🎁';
    if (lower.contains('tally') || lower.contains('tax') || lower.contains('accounting')) return '📊';
    if (lower.contains('lend') || lower.contains('loan') || lower.contains('borrow')) return '🤝';
    if (lower.contains('salary') || lower.contains('pay') || lower.contains('wage')) return '💰';
    if (lower.contains('rent') || lower.contains('house') || lower.contains('mortgage')) return '🏠';
    if (lower.contains('grocer')) return '🛒';
    if (lower.contains('entertain') || lower.contains('movie') || lower.contains('game')) return '🎮';
    if (lower.contains('health') || lower.contains('medic') || lower.contains('doctor')) return '⚕️';
    if (lower.contains('shop') || lower.contains('cloth')) return '🛍️';
    if (lower.contains('utilit') || lower.contains('bill') || lower.contains('electric') || lower.contains('water')) return '⚡';
    if (lower.contains('travel') || lower.contains('flight') || lower.contains('hotel')) return '✈️';
    if (lower.contains('education') || lower.contains('school') || lower.contains('book')) return '📚';
    if (lower.contains('gift') || lower.contains('donation')) return '🎀';
    if (lower.contains('gym') || lower.contains('fitness') || lower.contains('sport')) return '🏋️';
    if (lower.contains('pet')) return '🐾';
    if (lower.contains('beauty') || lower.contains('salon') || lower.contains('hair')) return '💇';
    
    return '📦'; // Default icon
  }

  Future<void> _restorePhotoFromFirestore(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (user == null) return;
      final data = doc.data();
      if (data == null || !data.containsKey('photoBase64')) return;
      final base64Str = data['photoBase64'] as String;
      
      Uint8List bytes;
      try {
        bytes = base64Decode(base64Str);
      } on FormatException {
        debugPrint('Profile photo data corrupted in Firestore — skipping restore.');
        return;
      }
      
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/profile_photo_$uid.jpg';
      await dart_io.File(filePath).writeAsBytes(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_photo_$uid', filePath);
      user = AppUser(uid: uid, email: user?.email ?? '', photoPath: filePath, name: user?.name);
      notifyListeners();
    } catch (e) {
      debugPrint('Error restoring photo from Firestore: $e');
    }
  }

  Future<void> pickProfilePhoto() async {
    if (user == null) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // compress to reduce Firestore payload
        maxWidth: 512,
        maxHeight: 512,
      );
      if (pickedFile != null) {
        // Copy to permanent app documents directory
        final dir = await getApplicationDocumentsDirectory();
        final destPath = '${dir.path}/profile_photo_${user!.uid}.jpg';
        final destFile = await dart_io.File(pickedFile.path).copy(destPath);

        // Save path locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo_${user!.uid}', destFile.path);

        // Upload base64-encoded image to Firestore
        final bytes = await destFile.readAsBytes();
        final base64Str = base64Encode(bytes);
        await _db.collection('users').doc(user!.uid).set(
          {'photoBase64': base64Str},
          SetOptions(merge: true),
        );

        user = AppUser(uid: user!.uid, email: user!.email, photoPath: destFile.path, name: user!.name);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error picking profile photo: $e');
    }
  }

  Future<void> updateUserName(String newName) async {
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_name_${user!.uid}', newName);
      user = AppUser(uid: user!.uid, email: user!.email, photoPath: user!.photoPath, name: newName);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating username: $e");
    }
  }
}

List<List<dynamic>> _parseCsvInBackground(List<int> bytes) {
  String csvString;
  try {
    csvString = utf8.decode(bytes);
  } catch (e) {
    csvString = latin1.decode(bytes);
  }
  
  csvString = CsvParser.cleanCsvString(csvString);
  final delimiter = CsvParser.detectCsvDelimiter(csvString);
  
  final lines = csvString.split(RegExp(r'\r\n|\r|\n'));
  final List<List<dynamic>> rows = [];
  for (var line in lines) {
    if (line.trim().isEmpty) continue;
    rows.add(CsvParser.parseCsvLine(line, delimiter));
  }
  return rows;
}
