import 'package:intl/intl.dart';

final NumberFormat _indianCurrencyFormatter = NumberFormat.decimalPattern('en_IN')
  ..minimumFractionDigits = 2
  ..maximumFractionDigits = 2;

extension CurrencyFormat on double {
  String formatIndianCurrency() {
    return _indianCurrencyFormatter.format(this);
  }
}
