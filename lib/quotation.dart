import 'dart:convert';

enum TaxCategory { material, labour, exempt, custom }

enum QuotationRecordType { draft, edited }

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
    this.showLeftStamp = true,
    this.showRightStamp = true,
    List<String>? customStamps,
    List<bool>? customStampVisibility,
    this.recordType = QuotationRecordType.draft,
    this.sourceName = '',
    this.sourceText = '',
    this.documentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : id = id ?? 'quotation-${DateTime.now().microsecondsSinceEpoch}',
       customStamps = customStamps ?? [],
       customStampVisibility = customStampVisibility ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String title;
  String fileName;
  final List<QuotationLine> lines;
  String leftStamp;
  String rightStamp;
  bool showStampBlocks;
  bool showLeftStamp;
  bool showRightStamp;
  final List<String> customStamps;
  final List<bool> customStampVisibility;
  QuotationRecordType recordType;
  String sourceName;
  String sourceText;
  DateTime? documentDate;
  final DateTime createdAt;
  DateTime updatedAt;

  bool customStampIsVisible(int index) =>
      index >= customStampVisibility.length || customStampVisibility[index];

  Quotation copy({String? id, QuotationRecordType? recordType}) => Quotation(
    id: id,
    title: title,
    fileName: fileName,
    lines: lines.map((line) => line.copy()).toList(),
    leftStamp: leftStamp,
    rightStamp: rightStamp,
    showStampBlocks: showStampBlocks,
    showLeftStamp: showLeftStamp,
    showRightStamp: showRightStamp,
    customStamps: List<String>.from(customStamps),
    customStampVisibility: List<bool>.from(customStampVisibility),
    recordType: recordType ?? this.recordType,
    sourceName: sourceName,
    sourceText: sourceText,
    documentDate: documentDate,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

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
    'showLeftStamp': showLeftStamp,
    'showRightStamp': showRightStamp,
    'customStamps': customStamps,
    'customStampVisibility': customStampVisibility,
    'recordType': recordType.name,
    'sourceName': sourceName,
    'sourceText': sourceText,
    'documentDate': documentDate?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
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
      showLeftStamp: json['showLeftStamp'] as bool? ?? true,
      showRightStamp: json['showRightStamp'] as bool? ?? true,
      customStamps:
          (json['customStamps'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          [],
      customStampVisibility:
          (json['customStampVisibility'] as List<dynamic>?)
              ?.map((value) => value as bool)
              .toList() ??
          [],
      recordType: QuotationRecordType.values.byName(
        json['recordType'] as String? ?? QuotationRecordType.draft.name,
      ),
      sourceName: json['sourceName'] as String? ?? '',
      sourceText: json['sourceText'] as String? ?? '',
      documentDate: json['documentDate'] == null
          ? null
          : DateTime.tryParse(json['documentDate'] as String),
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
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
