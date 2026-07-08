class CsvParser {
  /// Cleans the raw CSV input string by stripping byte order marks (BOM)
  /// and any separator metadata headers (e.g. `sep=;`).
  static String cleanCsvString(String input) {
    var cleaned = input.trim();
    if (cleaned.startsWith('\ufeff')) {
      cleaned = cleaned.substring(1).trim();
    }
    if (cleaned.toLowerCase().startsWith('sep=')) {
      final newlineIndex = cleaned.indexOf(RegExp(r'\r\n|\r|\n'));
      if (newlineIndex != -1) {
        cleaned = cleaned.substring(newlineIndex).trim();
      }
    }
    return cleaned;
  }

  /// Detects the field delimiter by sampling up to 10 rows and scoring
  /// potential delimiters (, ; \t |) based on volume and consistency.
  static String detectCsvDelimiter(String csvString) {
    final lines = csvString.split(RegExp(r'\r\n|\r|\n'));
    final candidates = [',', ';', '\t', '|'];
    String bestDelimiter = ',';
    int maxScore = -1;

    for (var delim in candidates) {
      int totalCount = 0;
      int lastCount = -1;
      int consistency = 0;

      int checkedLines = 0;
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        checkedLines++;
        if (checkedLines > 10) break;

        int count = 0;
        bool inQuotes = false;
        for (int i = 0; i < line.length; i++) {
          if (line[i] == '"') {
            inQuotes = !inQuotes;
          } else if (line[i] == delim && !inQuotes) {
            count++;
          }
        }

        if (count > 0) {
          totalCount += count;
          if (lastCount != -1 && count == lastCount) {
            consistency += 2;
          }
          lastCount = count;
        }
      }

      final score = totalCount + consistency;
      if (score > maxScore) {
        maxScore = score;
        bestDelimiter = delim;
      }
    }

    return bestDelimiter;
  }

  /// Parses a single line of CSV into its constituent fields,
  /// respecting quoted strings and trimming outer quotes/whitespace.
  static List<String> parseCsvLine(String line, String delimiter) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == delimiter && !inQuotes) {
        fields.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString().trim());

    return fields.map((f) {
      var s = f.trim();
      while (s.startsWith('"') && s.endsWith('"') && s.length >= 2) {
        s = s.substring(1, s.length - 1).trim();
      }
      return s;
    }).toList();
  }
}
