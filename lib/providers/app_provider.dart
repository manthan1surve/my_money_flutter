import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
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
import '../models/models.dart';
import '../core/csv_parser.dart';

class AppProvider extends ChangeNotifier {
  AppUser? user;
  List<Account> accounts = [];
  List<TransactionModel> transactions = [];
  List<CategoryModel> categories = [];
  bool loading = true;
  bool hasSeenOnboarding = false;
  CurrencyModel currency = CurrencyModel(code: 'USD', symbol: '\$', name: 'United States Dollar');
  DateTime currentDate = DateTime.now();

  StreamSubscription? _accountsSub;
  StreamSubscription? _transactionsSub;
  StreamSubscription? _categoriesSub;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AppProvider() {
    _init();
  }

  Future<void> _init() async {
    await _loadCurrency();
    await _loadOnboardingStatus();
    

    _auth.authStateChanges().listen((User? firebaseUser) async {
      if (firebaseUser != null) {
        final prefs = await SharedPreferences.getInstance();
        final photoPath = prefs.getString('profile_photo_${firebaseUser.uid}');
        user = AppUser(uid: firebaseUser.uid, email: firebaseUser.email ?? '', photoPath: photoPath);
        _fetchUserData();
      } else {
        user = null;
        accounts = [];
        transactions = [];
        categories = [];
        _cancelSubscriptions();
        loading = false;
        notifyListeners();
      }
    });
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

  void _cancelSubscriptions() {
    _accountsSub?.cancel();
    _transactionsSub?.cancel();
    _categoriesSub?.cancel();
  }

  Future<void> refreshData() async {
    _cancelSubscriptions();
    await _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user == null) return;
    
    loading = true;
    notifyListeners();
    
    final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
    final transRef = _db.collection('users').doc(user!.uid).collection('transactions');
    final categoriesRef = _db.collection('users').doc(user!.uid).collection('categories');

    try {
      // Load user preferences from Firebase
      final userDoc = await _db.collection('users').doc(user!.uid).get();
      if (userDoc.exists && userDoc.data() != null && userDoc.data()!.containsKey('currency')) {
        final decoded = CurrencyModel.fromMap(userDoc.data()!['currency']);
        
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
        
        // Also update local prefs so it's ready on next immediate startup
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_currency', json.encode(currency.toMap()));
      }



      // Seed defaults if empty
      final accountsSnap = await accountsRef.get();
      if (accountsSnap.docs.isEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        await accountsRef.add({'name': 'Bank', 'balance': 0, 'createdAt': now});
        await accountsRef.add({'name': 'Cash', 'balance': 0, 'createdAt': now});
        await accountsRef.add({'name': 'Savings', 'balance': 0, 'createdAt': now});
      }

      // Removed default categories seeding

      _accountsSub = accountsRef.snapshots().listen((snapshot) {
        accounts = snapshot.docs.map((doc) => Account.fromMap(doc.id, doc.data())).toList();
        accounts.sort((a, b) {
          final cmp = a.position.compareTo(b.position);
          if (cmp != 0) return cmp;
          return a.createdAt.compareTo(b.createdAt);
        });
        notifyListeners();
      });

      _transactionsSub = transRef.orderBy('date', descending: true).limit(2000).snapshots().listen((snapshot) {
        transactions = snapshot.docs.map((doc) => TransactionModel.fromMap(doc.id, doc.data())).toList();
        notifyListeners();
      });

      _categoriesSub = categoriesRef.snapshots().listen((snapshot) {
        categories = snapshot.docs.map((doc) => CategoryModel.fromMap(doc.id, doc.data())).toList();
        loading = false;
        notifyListeners();
      });

    } catch (e) {
      debugPrint("Error fetching user data: $e");
      loading = false;
      notifyListeners();
    }
  }

  Future<void> updateAccountsOrder(List<Account> reorderedList) async {
    if (user == null) return;
    
    // Proactively/optimistically update local state
    accounts = List.from(reorderedList);
    notifyListeners();

    try {
      final batch = _db.batch();
      final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
      for (int i = 0; i < reorderedList.length; i++) {
        final acc = reorderedList[i];
        batch.update(accountsRef.doc(acc.id), {'position': i});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to update accounts order: $e');
    }
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    if (user == null) return;
    final transRef = _db.collection('users').doc(user!.uid).collection('transactions');
    final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
    
    final batch = _db.batch();
    final newTransRef = transRef.doc();
    batch.set(newTransRef, transaction.toMap());
    
    if (transaction.type == 'transfer') {
      batch.update(accountsRef.doc(transaction.accountId), {'balance': FieldValue.increment(-transaction.amount)});
      if (transaction.toAccountId.isNotEmpty) {
        batch.update(accountsRef.doc(transaction.toAccountId), {'balance': FieldValue.increment(transaction.amount)});
      }
    } else {
      final change = transaction.type == 'income' ? transaction.amount : -transaction.amount;
      batch.update(accountsRef.doc(transaction.accountId), {'balance': FieldValue.increment(change)});
    }
    
    await batch.commit();
  }

  Future<void> deleteTransaction(TransactionModel transaction) async {
    if (user == null) return;
    final transRef = _db.collection('users').doc(user!.uid).collection('transactions');
    final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
    
    final batch = _db.batch();
    batch.delete(transRef.doc(transaction.id));
    
    if (transaction.type == 'transfer') {
      batch.update(accountsRef.doc(transaction.accountId), {'balance': FieldValue.increment(transaction.amount)});
      if (transaction.toAccountId.isNotEmpty) {
        batch.update(accountsRef.doc(transaction.toAccountId), {'balance': FieldValue.increment(-transaction.amount)});
      }
    } else {
      final change = transaction.type == 'income' ? -transaction.amount : transaction.amount;
      batch.update(accountsRef.doc(transaction.accountId), {'balance': FieldValue.increment(change)});
    }
    
    await batch.commit();
  }

  Future<void> updateTransaction(TransactionModel oldTx, TransactionModel newTx) async {
    if (user == null) return;
    final transRef = _db.collection('users').doc(user!.uid).collection('transactions');
    final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
    
    final batch = _db.batch();
    batch.update(transRef.doc(oldTx.id), newTx.toMap());
    
    // Reverse oldTx
    if (oldTx.type == 'transfer') {
      batch.update(accountsRef.doc(oldTx.accountId), {'balance': FieldValue.increment(oldTx.amount)});
      if (oldTx.toAccountId.isNotEmpty) {
        batch.update(accountsRef.doc(oldTx.toAccountId), {'balance': FieldValue.increment(-oldTx.amount)});
      }
    } else {
      final change = oldTx.type == 'income' ? -oldTx.amount : oldTx.amount;
      batch.update(accountsRef.doc(oldTx.accountId), {'balance': FieldValue.increment(change)});
    }

    // Apply newTx
    if (newTx.type == 'transfer') {
      batch.update(accountsRef.doc(newTx.accountId), {'balance': FieldValue.increment(-newTx.amount)});
      if (newTx.toAccountId.isNotEmpty) {
        batch.update(accountsRef.doc(newTx.toAccountId), {'balance': FieldValue.increment(newTx.amount)});
      }
    } else {
      final change = newTx.type == 'income' ? newTx.amount : -newTx.amount;
      batch.update(accountsRef.doc(newTx.accountId), {'balance': FieldValue.increment(change)});
    }
    
    await batch.commit();
  }
  
  Future<void> addAccount(String name, double balance) async {
    if (user == null) return;
    final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
    await accountsRef.add({
      'name': name,
      'balance': balance,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'position': accounts.length,
    });
  }

  Future<void> updateAccount(String id, String name, double balance) async {
    if (user == null) return;
    final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
    await accountsRef.doc(id).update({'name': name, 'balance': balance});
  }

  Future<void> deleteAccount(String id) async {
    if (user == null) return;
    final accountsRef = _db.collection('users').doc(user!.uid).collection('accounts');
    await accountsRef.doc(id).delete();
  }
  
  Future<void> addCategory(String name, String icon, String type) async {
    if (user == null) return;
    final categoriesRef = _db.collection('users').doc(user!.uid).collection('categories');
    await categoriesRef.add({'name': name, 'icon': icon, 'type': type});
  }

  Future<void> updateCategory(String id, String name, String icon, String type) async {
    if (user == null) return;
    final categoriesRef = _db.collection('users').doc(user!.uid).collection('categories');
    await categoriesRef.doc(id).update({'name': name, 'icon': icon, 'type': type});
  }

  Future<void> deleteCategory(String id) async {
    if (user == null) return;
    final categoriesRef = _db.collection('users').doc(user!.uid).collection('categories');
    await categoriesRef.doc(id).delete();
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



  Future<void> exportTransactionsCSV() async {
    if (user == null) return;
    
    List<List<dynamic>> rows = [];
    rows.add(['TIME', 'TYPE', 'AMOUNT', 'CATEGORY', 'ACCOUNT', 'TO ACCOUNT', 'NOTES']);
    
    final DateFormat formatter = DateFormat('MMM dd, yyyy');
    
    int count = 0;
    for (var tx in transactions) {
      if (++count % 50 == 0) await Future.delayed(const Duration(milliseconds: 1));
      String catName = categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => CategoryModel(id: '', name: 'Unknown', icon: '', type: tx.type)).name;
      String accName = accounts.firstWhere((a) => a.id == tx.accountId, orElse: () => Account(id: '', name: 'Unknown', balance: 0, createdAt: 0)).name;
      
      String toAccName = '';
      if (tx.type == 'transfer' && tx.toAccountId.isNotEmpty) {
        try {
          toAccName = accounts.firstWhere((a) => a.id == tx.toAccountId).name;
        } catch (_) {}
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
      int lineCount = 0;
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        rows.add(CsvParser.parseCsvLine(line, delimiter));
        if (++lineCount % 50 == 0) await Future.delayed(const Duration(milliseconds: 1));
      }
      
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
        
        if (accIdx == -1) {
           final now = DateTime.now().millisecondsSinceEpoch;
           final bDoc = await accountsRef.add({'name': 'Bank', 'balance': 0, 'createdAt': now});
           accounts.add(Account(id: bDoc.id, name: 'Bank', balance: 0, createdAt: now));
           final cDoc = await accountsRef.add({'name': 'Cash', 'balance': 0, 'createdAt': now});
           accounts.add(Account(id: cDoc.id, name: 'Cash', balance: 0, createdAt: now));
           final sDoc = await accountsRef.add({'name': 'Savings', 'balance': 0, 'createdAt': now});
           accounts.add(Account(id: sDoc.id, name: 'Savings', balance: 0, createdAt: now));
        }
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
        double amount = double.tryParse(row[amountIdx].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
        
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
        Account? acc;
        for (final a in accounts) {
          if (a.name.toLowerCase() == accountName.toLowerCase()) {
            acc = a;
            break;
          }
        }
        
        String accId;
        if (acc == null) {
          final doc = await accountsRef.add({'name': accountName, 'balance': 0, 'createdAt': DateTime.now().millisecondsSinceEpoch});
          accId = doc.id;
          acc = Account(id: accId, name: accountName, balance: 0, createdAt: DateTime.now().millisecondsSinceEpoch);
          accounts.add(acc);
        } else {
          accId = acc.id;
        }

        // Handle target account for transfers
        String toAccId = '';
        if (type == 'transfer' && toAccountName.isNotEmpty) {
            Account? toAcc;
            for (final a in accounts) {
              if (a.name.toLowerCase() == toAccountName.toLowerCase()) {
                toAcc = a;
                break;
              }
            }
            
            if (toAcc == null) {
              final doc = await accountsRef.add({'name': toAccountName, 'balance': 0, 'createdAt': DateTime.now().millisecondsSinceEpoch});
              toAccId = doc.id;
              toAcc = Account(id: toAccId, name: toAccountName, balance: 0, createdAt: DateTime.now().millisecondsSinceEpoch);
              accounts.add(toAcc);
            } else {
              toAccId = toAcc.id;
            }
          }
        
        // Find or create category
        CategoryModel? cat;
        for (final c in categories) {
          if (c.name.toLowerCase() == categoryName.toLowerCase()) {
            cat = c;
            break;
          }
        }
        
        String catId;
        if (cat == null) {
          final icon = _getIconForCategory(categoryName);
          final doc = await categoriesRef.add({'name': categoryName, 'icon': icon, 'type': type});
          catId = doc.id;
          cat = CategoryModel(id: catId, name: categoryName, icon: icon, type: type);
          categories.add(cat);
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
             Account toAcc = accounts.firstWhere((a) => a.id == toAccId);
             double toBalance = accountBalanceUpdates[toAccId] ?? toAcc.balance;
             toBalance += amount; // Add to target
             accountBalanceUpdates[toAccId] = toBalance;
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
        throw Exception("No valid transactions found in the file. Make sure the file format is correct (Time, Type, Amount, Category, Account, Notes).");
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

      // Seed defaults
      final now = DateTime.now().millisecondsSinceEpoch;
      await accountsRef.add({'name': 'Bank', 'balance': 0, 'createdAt': now});
      await accountsRef.add({'name': 'Cash', 'balance': 0, 'createdAt': now});
      await accountsRef.add({'name': 'Savings', 'balance': 0, 'createdAt': now});
      
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
      
      // Wait for all local writes to sync with Firestore cloud backend.
      // Timeout after 5 seconds to prevent freezing the app if the user is completely offline.
      await _db.waitForPendingWrites().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Logout warning: Pending writes sync failed or timed out: $e");
    } finally {
      loading = false;
      try {
        await GoogleSignIn().signOut();
      } catch (e) {
        debugPrint("Google Sign-Out Error: $e");
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

  Future<void> pickProfilePhoto() async {
    if (user == null) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo_${user!.uid}', pickedFile.path);
        user = AppUser(uid: user!.uid, email: user!.email, photoPath: pickedFile.path);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error picking profile photo: $e");
    }
  }
}
