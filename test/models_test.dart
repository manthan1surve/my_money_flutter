import 'package:flutter_test/flutter_test.dart';
import 'package:my_money_flutter/models/models.dart';

void main() {
  group('Account Model Tests', () {
    test('Account.fromMap parses standard values correctly', () {
      final data = {
        'name': 'Chase Checking',
        'balance': 1500.50,
        'createdAt': 1625616000000,
        'position': 2,
      };
      final account = Account.fromMap('acc-123', data);

      expect(account.id, 'acc-123');
      expect(account.name, 'Chase Checking');
      expect(account.balance, 1500.50);
      expect(account.createdAt, 1625616000000);
      expect(account.position, 2);
    });

    test('Account.fromMap handles missing/null values gracefully', () {
      final data = <String, dynamic>{};
      final account = Account.fromMap('acc-empty', data);

      expect(account.id, 'acc-empty');
      expect(account.name, '');
      expect(account.balance, 0.0);
      expect(account.createdAt, 0);
      expect(account.position, 0);
    });

    test('Account.toMap serializes properties correctly', () {
      final account = Account(
        id: 'acc-456',
        name: 'Pocket Cash',
        balance: 150.0,
        createdAt: 1625617000000,
        position: 1,
      );
      final map = account.toMap();

      expect(map['name'], 'Pocket Cash');
      expect(map['balance'], 150.0);
      expect(map['createdAt'], 1625617000000);
      expect(map['position'], 1);
    });
  });

  group('TransactionModel Tests', () {
    test('TransactionModel.fromMap parses standard values correctly', () {
      final data = {
        'amount': 25.99,
        'type': 'expense',
        'categoryId': 'cat-food',
        'accountId': 'acc-123',
        'toAccountId': '',
        'note': 'Lunch at Subway',
        'date': 1625618000000,
      };
      final tx = TransactionModel.fromMap('tx-1', data);

      expect(tx.id, 'tx-1');
      expect(tx.amount, 25.99);
      expect(tx.type, 'expense');
      expect(tx.categoryId, 'cat-food');
      expect(tx.accountId, 'acc-123');
      expect(tx.toAccountId, '');
      expect(tx.note, 'Lunch at Subway');
      expect(tx.date, 1625618000000);
    });

    test('TransactionModel.fromMap handles null/missing values gracefully', () {
      final data = <String, dynamic>{};
      final tx = TransactionModel.fromMap('tx-empty', data);

      expect(tx.id, 'tx-empty');
      expect(tx.amount, 0.0);
      expect(tx.type, 'expense');
      expect(tx.categoryId, '');
      expect(tx.accountId, '');
      expect(tx.toAccountId, '');
      expect(tx.note, '');
      expect(tx.date, 0);
    });

    test('TransactionModel.toMap serializes properties correctly', () {
      final tx = TransactionModel(
        id: 'tx-2',
        amount: 500.0,
        type: 'transfer',
        categoryId: '',
        accountId: 'acc-123',
        toAccountId: 'acc-456',
        note: 'Savings transfer',
        date: 1625619000000,
      );
      final map = tx.toMap();

      expect(map['amount'], 500.0);
      expect(map['type'], 'transfer');
      expect(map['categoryId'], '');
      expect(map['accountId'], 'acc-123');
      expect(map['toAccountId'], 'acc-456');
      expect(map['note'], 'Savings transfer');
      expect(map['date'], 1625619000000);
    });
  });

  group('CategoryModel Tests', () {
    test('CategoryModel.fromMap parses standard values correctly', () {
      final data = {
        'name': 'Food & Drinks',
        'icon': '🍔',
        'type': 'expense',
      };
      final category = CategoryModel.fromMap('cat-1', data);

      expect(category.id, 'cat-1');
      expect(category.name, 'Food & Drinks');
      expect(category.icon, '🍔');
      expect(category.type, 'expense');
    });

    test('CategoryModel.fromMap handles null/missing values gracefully', () {
      final data = <String, dynamic>{};
      final category = CategoryModel.fromMap('cat-empty', data);

      expect(category.id, 'cat-empty');
      expect(category.name, '');
      expect(category.icon, '');
      expect(category.type, 'expense');
    });

    test('CategoryModel.toMap serializes properties correctly', () {
      final category = CategoryModel(
        id: 'cat-2',
        name: 'Salary',
        icon: '💰',
        type: 'income',
      );
      final map = category.toMap();

      expect(map['name'], 'Salary');
      expect(map['icon'], '💰');
      expect(map['type'], 'income');
    });
  });

  group('CurrencyModel Tests', () {
    test('CurrencyModel.fromMap parses standard values correctly', () {
      final data = {
        'code': 'INR',
        'symbol': '₹',
        'name': 'Indian Rupee',
      };
      final currency = CurrencyModel.fromMap(data);

      expect(currency.code, 'INR');
      expect(currency.symbol, '₹');
      expect(currency.name, 'Indian Rupee');
    });

    test('CurrencyModel.fromMap handles null/missing values gracefully', () {
      final data = <String, dynamic>{};
      final currency = CurrencyModel.fromMap(data);

      expect(currency.code, 'USD');
      expect(currency.symbol, '\$');
      expect(currency.name, 'United States Dollar');
    });

    test('CurrencyModel.toMap serializes properties correctly', () {
      final currency = CurrencyModel(
        code: 'EUR',
        symbol: '€',
        name: 'Euro',
      );
      final map = currency.toMap();

      expect(map['code'], 'EUR');
      expect(map['symbol'], '€');
      expect(map['name'], 'Euro');
    });
  });
}
