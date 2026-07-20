import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Persists all app data to SharedPreferences as JSON.
/// This is the primary data source — Firestore is only used to
/// push/pull deltas when connectivity is available.
class LocalStore {
  static const _keyAccounts = 'ls_accounts';
  static const _keyTransactions = 'ls_transactions';
  static const _keyCategories = 'ls_categories';
  static const _keyLastSynced = 'ls_last_synced';
  static const _keyPendingSync = 'ls_pending_sync';

  // ── Accounts ────────────────────────────────────────────────────────────

  static Future<void> saveAccounts(List<Account> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        accounts.map((a) => {'id': a.id, ...a.toMap()}).toList(),
      );
      await prefs.setString(_keyAccounts, encoded);
    } catch (e) {
      debugPrint('[LocalStore] saveAccounts error: \$e');
    }
  }

  static Future<List<Account>> loadAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyAccounts);
      if (raw == null) return [];
      final List<dynamic> list = json.decode(raw);
      return list
          .map((m) => Account.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[LocalStore] loadAccounts error: \$e');
      return [];
    }
  }

  // ── Transactions ─────────────────────────────────────────────────────────

  static Future<void> saveTransactions(List<TransactionModel> transactions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = await compute(_encodeTransactionsInBackground, transactions);
      await prefs.setString(_keyTransactions, encoded);
    } catch (e) {
      debugPrint('[LocalStore] saveTransactions error: $e');
    }
  }

  static Future<List<TransactionModel>> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyTransactions);
      if (raw == null) return [];
      return await compute(_parseTransactionsInBackground, raw);
    } catch (e) {
      debugPrint('[LocalStore] loadTransactions error: $e');
      return [];
    }
  }

  // ── Categories ───────────────────────────────────────────────────────────

  static Future<void> saveCategories(List<CategoryModel> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(
        categories.map((c) => {'id': c.id, ...c.toMap()}).toList(),
      );
      await prefs.setString(_keyCategories, encoded);
    } catch (e) {
      debugPrint('[LocalStore] saveCategories error: \$e');
    }
  }

  static Future<List<CategoryModel>> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyCategories);
      if (raw == null) return [];
      final List<dynamic> list = json.decode(raw);
      return list
          .map((m) => CategoryModel.fromMap(m['id'] as String, Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[LocalStore] loadCategories error: \$e');
      return [];
    }
  }

  // ── Sync metadata ────────────────────────────────────────────────────────

  static Future<DateTime?> getLastSyncedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_keyLastSynced);
      return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setLastSyncedAt(DateTime dt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastSynced, dt.millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<bool> getPendingSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyPendingSync) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPendingSync(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPendingSync, value);
    } catch (_) {}
  }

  // ── Clear (on logout) ────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccounts);
      await prefs.remove(_keyTransactions);
      await prefs.remove(_keyCategories);
      await prefs.remove(_keyLastSynced);
      await prefs.remove(_keyPendingSync);
    } catch (e) {
      debugPrint('[LocalStore] clearAll error: \$e');
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
