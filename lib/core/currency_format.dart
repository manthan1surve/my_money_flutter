import 'package:intl/intl.dart';

extension CurrencyFormat on double {
  String formatIndianCurrency() {
    final formatter = NumberFormat.decimalPattern('en_IN');
    formatter.minimumFractionDigits = 2;
    formatter.maximumFractionDigits = 2;
    return formatter.format(this);
  }
}
