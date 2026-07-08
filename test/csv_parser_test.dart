import 'package:flutter_test/flutter_test.dart';
import 'package:my_money_flutter/core/csv_parser.dart';

void main() {
  group('CsvParser - cleanCsvString Tests', () {
    test('removes UTF-8 BOM if present', () {
      const input = '\ufeffTIME,TYPE,AMOUNT\n2023-01-01,expense,100';
      final output = CsvParser.cleanCsvString(input);
      expect(output.startsWith('\ufeff'), isFalse);
      expect(output, 'TIME,TYPE,AMOUNT\n2023-01-01,expense,100');
    });

    test('removes sep= metadata header if present', () {
      const input = 'sep=;\nTIME;TYPE;AMOUNT\n2023-01-01;expense;100';
      final output = CsvParser.cleanCsvString(input);
      expect(output, 'TIME;TYPE;AMOUNT\n2023-01-01;expense;100');
    });

    test('removes both BOM and sep= header', () {
      const input = '\ufeffsep=,\nTIME,TYPE,AMOUNT\n2023-01-01,expense,100';
      final output = CsvParser.cleanCsvString(input);
      expect(output, 'TIME,TYPE,AMOUNT\n2023-01-01,expense,100');
    });
  });

  group('CsvParser - detectCsvDelimiter Tests', () {
    test('detects comma delimiter correctly', () {
      const input = 'TIME,TYPE,AMOUNT\n2023-01-01,expense,100\n2023-01-02,income,200';
      expect(CsvParser.detectCsvDelimiter(input), ',');
    });

    test('detects semicolon delimiter correctly', () {
      const input = 'TIME;TYPE;AMOUNT\n2023-01-01;expense;100\n2023-01-02;income;200';
      expect(CsvParser.detectCsvDelimiter(input), ';');
    });

    test('detects tab delimiter correctly', () {
      const input = 'TIME\tTYPE\tAMOUNT\n2023-01-01\texpense\t100\n2023-01-02\tincome\t200';
      expect(CsvParser.detectCsvDelimiter(input), '\t');
    });

    test('detects pipe delimiter correctly', () {
      const input = 'TIME|TYPE|AMOUNT\n2023-01-01|expense|100\n2023-01-02|income|200';
      expect(CsvParser.detectCsvDelimiter(input), '|');
    });

    test('ignores candidate delimiters inside double quotes', () {
      const input = 'TIME,TYPE,NOTE\n2023-01-01,expense,"Lunch; at Subway"\n2023-01-02,income,"Bonus; reward"';
      // Semicolons are inside quotes, so the true delimiter is still comma
      expect(CsvParser.detectCsvDelimiter(input), ',');
    });
  });

  group('CsvParser - parseCsvLine Tests', () {
    test('splits simple unquoted fields', () {
      const line = '2023-01-01,expense,100,Food,Bank';
      final fields = CsvParser.parseCsvLine(line, ',');
      expect(fields, ['2023-01-01', 'expense', '100', 'Food', 'Bank']);
    });

    test('splits fields and removes surrounding quotes', () {
      const line = '"2023-01-01","expense","100","Food","Bank"';
      final fields = CsvParser.parseCsvLine(line, ',');
      expect(fields, ['2023-01-01', 'expense', '100', 'Food', 'Bank']);
    });

    test('preserves delimiter characters inside quoted fields', () {
      const line = '2023-01-01,expense,100,"Food, Dining & Drinks",Bank';
      final fields = CsvParser.parseCsvLine(line, ',');
      expect(fields, ['2023-01-01', 'expense', '100', 'Food, Dining & Drinks', 'Bank']);
    });

    test('handles empty fields correctly', () {
      const line = '2023-01-01,expense,100,,Bank';
      final fields = CsvParser.parseCsvLine(line, ',');
      expect(fields, ['2023-01-01', 'expense', '100', '', 'Bank']);
    });

    test('trims whitespace around values', () {
      const line = ' 2023-01-01 , expense , 100 , " Food " , Bank ';
      final fields = CsvParser.parseCsvLine(line, ',');
      expect(fields, ['2023-01-01', 'expense', '100', 'Food', 'Bank']);
    });
  });
}
