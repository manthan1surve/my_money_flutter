import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Persists app data locally.
/// - Large transaction histories are stored in atomic local files via path_provider
///   to prevent SharedPreferences 1MB Binder crashes and main isolate serialization lag.
/// - Accounts, categories, and sync metadata are kept in SharedPreferences.
/// - Provides automatic migration from legacy SharedPreferences transaction blobs.
class LocalStore {
  static const _keyAccounts = 'ls_accounts';
  static const _keyTransactions = 'ls_transactions'; // Legacy key for migration
  static const _keyCategories = 'ls_categories';
  static const _keyLastSynced = 'ls_last_synced';
  static const _keyPendingSync = 'ls_pending_sync';
  static const _keyPendingDeltas = 'ls_pending_deltas';
  static const _transactionsFileName = 'transactions_store.json';

  static SharedPreferences? _prefs;
  static File? _transactionsFile;

  static Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<File> _getTransactionsFile() async {
    if (_transactionsFile != null) return _transactionsFile!;
    final dir = await getApplicationDocumentsDirectory();
    _transactionsFile = File('${dir.path}/$_transactionsFileName');
    return _transactionsFile!;
  }

  // ── Accounts ────────────────────────────────────────────────────────────

  static Future<void> saveAccounts(List<Account> accounts) async {
    try {
      final prefs = await _getPrefs();
      final encoded = json.encode(
        accounts.map((a) => {'id': a.id, ...a.toMap()}).toList(),
      );
      await prefs.setString(_keyAccounts, encoded);
    } catch (e) {
      debugPrint('[LocalStore] saveAccounts error: $e');
    }
  }

  static Future<List<Account>> loadAccounts() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_keyAccounts);
      if (raw == null) return [];
      final List<dynamic> list = json.decode(raw);
      return list
          .map((m) => Account.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[LocalStore] loadAccounts error: $e');
      return [];
    }
  }

  // ── Transactions (File-Backed with Atomic Writes) ────────────────────────

  static Future<void> saveTransactions(List<TransactionModel> transactions) async {
    try {
      final file = await _getTransactionsFile();
      final encoded = await compute(_encodeTransactionsInBackground, transactions);
      
      // Atomic write: write to temp file then rename to prevent corruption on sudden termination
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(encoded, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e) {
      debugPrint('[LocalStore] saveTransactions error: $e');
    }
  }

  static Future<List<TransactionModel>> loadTransactions() async {
    try {
      final file = await _getTransactionsFile();
      
      // 1. If modern file store exists, read from it
      if (await file.exists()) {
        final raw = await file.readAsString();
        if (raw.isNotEmpty) {
          return await compute(_parseTransactionsInBackground, raw);
        }
      }

      // 2. Fallback / One-time migration: check legacy SharedPreferences
      final prefs = await _getPrefs();
      final legacyRaw = prefs.getString(_keyTransactions);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        debugPrint('[LocalStore] Migrating legacy SharedPreferences transactions to file store...');
        final transactions = await compute(_parseTransactionsInBackground, legacyRaw);
        await saveTransactions(transactions);
        await prefs.remove(_keyTransactions);
        debugPrint('[LocalStore] Migration completed successfully.');
        return transactions;
      }

      return [];
    } catch (e) {
      debugPrint('[LocalStore] loadTransactions error: $e');
      return [];
    }
  }

  // ── Categories ───────────────────────────────────────────────────────────

  static Future<void> saveCategories(List<CategoryModel> categories) async {
    try {
      final prefs = await _getPrefs();
      final encoded = json.encode(
        categories.map((c) => {'id': c.id, ...c.toMap()}).toList(),
      );
      await prefs.setString(_keyCategories, encoded);
    } catch (e) {
      debugPrint('[LocalStore] saveCategories error: $e');
    }
  }

  static Future<List<CategoryModel>> loadCategories() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_keyCategories);
      if (raw == null) return [];
      final List<dynamic> list = json.decode(raw);
      return list
          .map((m) => CategoryModel.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[LocalStore] loadCategories error: $e');
      return [];
    }
  }

  // ── Sync metadata & Offline Delta Queue ──────────────────────────────────

  static Future<DateTime?> getLastSyncedAt() async {
    try {
      final prefs = await _getPrefs();
      final ms = prefs.getInt(_keyLastSynced);
      return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastSyncedAt(DateTime dt) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(_keyLastSynced, dt.millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<bool> getPendingSync() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(_keyPendingSync) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPendingSync(bool value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(_keyPendingSync, value);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadPendingDeltas() async {
    try {
      final prefs = await _getPrefs();
      final raw = prefs.getString(_keyPendingDeltas);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> decoded = json.decode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('[LocalStore] loadPendingDeltas error: $e');
      return [];
    }
  }

  static Future<void> savePendingDeltas(List<Map<String, dynamic>> deltas) async {
    try {
      final prefs = await _getPrefs();
      if (deltas.isEmpty) {
        await prefs.remove(_keyPendingDeltas);
      } else {
        await prefs.setString(_keyPendingDeltas, json.encode(deltas));
      }
    } catch (e) {
      debugPrint('[LocalStore] savePendingDeltas error: $e');
    }
  }

  // ── Clear (on logout) ────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyAccounts);
      await prefs.remove(_keyTransactions);
      await prefs.remove(_keyCategories);
      await prefs.remove(_keyLastSynced);
      await prefs.remove(_keyPendingSync);
      await prefs.remove(_keyPendingDeltas);
      _prefs = null;

      try {
        final file = await _getTransactionsFile();
        if (await file.exists()) {
          await file.delete();
        }
        final tempFile = File('${file.path}.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      _transactionsFile = null;
    } catch (e) {
      debugPrint('[LocalStore] clearAll error: $e');
    }
  }
}

// Top-level functions for background isolate processing
String _encodeTransactionsInBackground(List<TransactionModel> transactions) {
  return json.encode(
    transactions.map((t) => {'id': t.id, ...t.toMap()}).toList(),
  );
}

List<TransactionModel> _parseTransactionsInBackground(String raw) {
  final List<dynamic> list = json.decode(raw);
  return list
      .map((m) => TransactionModel.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
      .toList();
}
