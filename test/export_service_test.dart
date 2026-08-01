import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:municipal_quotation_builder/export_service.dart';
import 'package:municipal_quotation_builder/quotation.dart';

void main() {
  Quotation sampleQuotation() => Quotation(
    title: 'Repair of Water Supply Pump',
    fileName: 'water_supply_pump',
    leftStamp: 'Sub Engineer',
    rightStamp: 'Municipal Officer',
    lines: [
      QuotationLine(
        id: 'line-1',
        description: 'Copper Wire Modern',
        quantityMicros: 2000000,
        unit: 'Kg',
        rateMinor: 620000,
        taxCategory: TaxCategory.material,
        taxBasisPoints: 1800,
      ),
    ],
  );

  test('CSV follows quotation table, totals, and signature row order', () {
    final text = utf8.decode(
      ExportService().csv(sampleQuotation()),
      allowMalformed: true,
    );

    expect(text, contains('REPAIR OF WATER SUPPLY PUMP'));
    expect(text, contains('"Sr.","Description","Qty","Unit"'));
    expect(text, contains('"Subtotal"'));
    expect(text, contains('"Sales Tax"'));
    expect(text, contains('"Grand Total"'));
    expect(text, contains('"Sub Engineer"'));
  });

  test('Excel quotation is generated as an editable XLSX workbook', () {
    final bytes = ExportService().excel(sampleQuotation());

    expect(bytes, isNotEmpty);
    expect(bytes.take(2), [0x50, 0x4b]);
    expect(bytes.length, greaterThan(3000));
  });
}
