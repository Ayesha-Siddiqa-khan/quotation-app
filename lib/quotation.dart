import 'dart:convert';

enum TaxCategory { material, labour, exempt, custom }

class QuotationLine {
  QuotationLine({
    required this.id,
    required this.description,
    required this.quantityMicros,
    required this.unit,
    required this.rateMinor,
    required this.taxCategory,
    required this.taxBasisPoints,
  });

  final String id;
  String description;
  int quantityMicros;
  String unit;
  int rateMinor;
  TaxCategory taxCategory;
  int taxBasisPoints;

  int get amountMinor => ((quantityMicros * rateMinor) + 500000) ~/ 1000000;
  int get salesTaxMinor => ((amountMinor * taxBasisPoints) + 5000) ~/ 10000;
  int get totalMinor => amountMinor + salesTaxMinor;

  QuotationLine copy({String? id}) => QuotationLine(
    id: id ?? this.id,
    description: description,
    quantityMicros: quantityMicros,
    unit: unit,
    rateMinor: rateMinor,
    taxCategory: taxCategory,
    taxBasisPoints: taxBasisPoints,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'description': description,
    'quantityMicros': quantityMicros,
    'unit': unit,
    'rateMinor': rateMinor,
    'taxCategory': taxCategory.name,
    'taxBasisPoints': taxBasisPoints,
  };

  factory QuotationLine.fromJson(Map<String, dynamic> json) => QuotationLine(
    id: json['id'] as String,
    description: json['description'] as String,
    quantityMicros: json['quantityMicros'] as int,
    unit: json['unit'] as String,
    rateMinor: json['rateMinor'] as int,
    taxCategory: TaxCategory.values.byName(json['taxCategory'] as String),
    taxBasisPoints: json['taxBasisPoints'] as int,
  );
}

class Quotation {
  Quotation({
    String? id,
    required this.title,
    required this.fileName,
    required this.lines,
    required this.leftStamp,
    required this.rightStamp,
    this.showStampBlocks = true,
    List<String>? customStamps,
  }) : id = id ?? 'quotation-${DateTime.now().microsecondsSinceEpoch}',
       customStamps = customStamps ?? [];

  final String id;
  String title;
  String fileName;
  final List<QuotationLine> lines;
  String leftStamp;
  String rightStamp;
  bool showStampBlocks;
  final List<String> customStamps;

  int get subtotalMinor => lines.fold(0, (sum, line) => sum + line.amountMinor);
  int get taxMinor => lines.fold(0, (sum, line) => sum + line.salesTaxMinor);
  int get grandTotalMinor => subtotalMinor + taxMinor;
  bool get isValid =>
      title.trim().isNotEmpty &&
      lines.isNotEmpty &&
      lines.every(
        (line) =>
            line.description.trim().isNotEmpty &&
            line.quantityMicros >= 0 &&
            line.rateMinor >= 0 &&
            line.taxBasisPoints >= 0 &&
            line.taxBasisPoints <= 10000,
      );

  String encode() => jsonEncode({
    'id': id,
    'title': title,
    'fileName': fileName,
    'lines': lines.map((line) => line.toJson()).toList(),
    'leftStamp': leftStamp,
    'rightStamp': rightStamp,
    'showStampBlocks': showStampBlocks,
    'customStamps': customStamps,
  });

  factory Quotation.decode(String value) {
    final json = jsonDecode(value) as Map<String, dynamic>;
    return Quotation(
      id: json['id'] as String?,
      title: json['title'] as String,
      fileName: json['fileName'] as String? ?? 'municipal_quotation',
      lines: (json['lines'] as List<dynamic>)
          .map((line) => QuotationLine.fromJson(line as Map<String, dynamic>))
          .toList(),
      leftStamp: json['leftStamp'] as String,
      rightStamp: json['rightStamp'] as String,
      showStampBlocks: json['showStampBlocks'] as bool? ?? true,
      customStamps:
          (json['customStamps'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          [],
    );
  }
}

int parseQuantityMicros(String raw) => _parseScaled(raw, 6);
int parseMoneyMinor(String raw) => _parseScaled(raw, 2);
int parseTaxBasisPoints(String raw) => _parseScaled(raw, 2);

int _parseScaled(String raw, int decimalPlaces) {
  final cleaned = raw.replaceAll(',', '').trim();
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(cleaned)) {
    throw const FormatException('Enter a valid positive number');
  }
  final parts = cleaned.split('.');
  final whole = int.parse(parts.first);
  final fraction = parts.length == 1 ? '' : parts[1];
  final padded = (fraction + ('0' * decimalPlaces)).substring(0, decimalPlaces);
  return whole * _pow10(decimalPlaces) +
      int.parse(padded.isEmpty ? '0' : padded);
}

int _pow10(int exponent) {
  var value = 1;
  for (var i = 0; i < exponent; i++) {
    value *= 10;
  }
  return value;
}
