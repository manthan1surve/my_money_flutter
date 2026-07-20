class AppUser {
  final String uid;
  final String email;
  final String? photoPath;
  final String? name;

  AppUser({required this.uid, required this.email, this.photoPath, this.name});
}

class Account {
  final String id;
  final String name;
  final double balance;
  final int createdAt;
  final int position;

  Account({
    required this.id,
    required this.name,
    required this.balance,
    required this.createdAt,
    this.position = 0,
  });

  factory Account.fromMap(String id, Map<String, dynamic> data) {
    return Account(
      id: id,
      name: data['name'] ?? '',
      balance: (data['balance'] ?? 0).toDouble(),
      createdAt: data['createdAt'] ?? 0,
      position: data['position'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'balance': balance,
      'createdAt': createdAt,
      'position': position,
    };
  }
}

class TransactionModel {
  final String id;
  final double amount;
  final String type; // 'expense', 'income', or 'transfer'
  final String categoryId;
  final String accountId;
  final String toAccountId;
  final String note;
  final int date; // timestamp

  TransactionModel({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId = '',
    required this.note,
    required this.date,
  });

  factory TransactionModel.fromMap(String id, Map<String, dynamic> data) {
    return TransactionModel(
      id: id,
      amount: (data['amount'] ?? 0).toDouble(),
      type: data['type'] ?? 'expense',
      categoryId: data['categoryId'] ?? '',
      accountId: data['accountId'] ?? '',
      toAccountId: data['toAccountId'] ?? '',
      note: data['note'] ?? '',
      date: data['date'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'note': note,
      'date': date,
    };
  }
}

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final String type;

  CategoryModel({required this.id, required this.name, required this.icon, required this.type});

  factory CategoryModel.fromMap(String id, Map<String, dynamic> data) {
    return CategoryModel(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '',
      type: data['type'] ?? 'expense',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'type': type,
    };
  }
}

class CurrencyModel {
  final String code;
  final String symbol;
  final String name;

  CurrencyModel({required this.code, required this.symbol, required this.name});

  factory CurrencyModel.fromMap(Map<String, dynamic> data) {
    return CurrencyModel(
      code: data['code'] ?? 'USD',
      symbol: data['symbol'] ?? '\$',
      name: data['name'] ?? 'United States Dollar',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'symbol': symbol,
      'name': name,
    };
  }
}
