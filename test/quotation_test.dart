import 'package:flutter_test/flutter_test.dart';
import 'package:municipal_quotation_builder/quotation.dart';

void main() {
  test('PRD copper wire calculation uses exact integer decimal arithmetic', () {
    final line = QuotationLine(
      id: '1',
      description: 'Copper Wire Modern',
      quantityMicros: parseQuantityMicros('11'),
      unit: 'Kg',
      rateMinor: parseMoneyMinor('6200'),
      taxCategory: TaxCategory.material,
      taxBasisPoints: parseTaxBasisPoints('18'),
    );

    expect(line.amountMinor, 6820000);
    expect(line.salesTaxMinor, 1227600);
    expect(line.totalMinor, 8047600);
  });

  test('PRD labour calculation defaults to 16 percent', () {
    final line = QuotationLine(
      id: '2',
      description: 'Rickshaw Fare',
      quantityMicros: parseQuantityMicros('2'),
      unit: 'Job',
      rateMinor: parseMoneyMinor('500'),
      taxCategory: TaxCategory.labour,
      taxBasisPoints: parseTaxBasisPoints('16'),
    );

    expect(line.amountMinor, 100000);
    expect(line.salesTaxMinor, 16000);
    expect(line.totalMinor, 116000);
  });

  test('draft serialization preserves manual positions', () {
    final quotation = Quotation(
      title: 'Test',
      fileName: 'test',
      lines: [],
      leftStamp: 'Sub Engineer',
      rightStamp: 'Municipal Officer',
      customStamps: ['Chief Officer'],
    );

    expect(Quotation.decode(quotation.encode()).customStamps, [
      'Chief Officer',
    ]);
  });

  test(
    'serialization preserves signature visibility and app-only metadata',
    () {
      final created = DateTime(2026, 7, 29, 13, 56);
      final quotation = Quotation(
        id: 'quotation-1',
        title: 'Repair of Motor 20HP at City Waterworks Tanki No. 2',
        fileName: 'Quotation for City Waterworks Tanki No. 2',
        lines: [],
        leftStamp: 'Sub Engineer',
        rightStamp: 'Municipal Officer',
        showLeftStamp: true,
        showRightStamp: false,
        customStamps: ['Chief Officer', 'Contractor'],
        customStampVisibility: [true, false],
        recordType: QuotationRecordType.edited,
        sourceName: 'CamScanner.pdf',
        sourceText: 'DATE 29/07/2026',
        documentDate: DateTime(2026, 7, 29),
        createdAt: created,
        updatedAt: created.add(const Duration(minutes: 5)),
      );

      final restored = Quotation.decode(quotation.encode());

      expect(restored.showLeftStamp, isTrue);
      expect(restored.showRightStamp, isFalse);
      expect(restored.customStampVisibility, [true, false]);
      expect(restored.recordType, QuotationRecordType.edited);
      expect(restored.sourceName, 'CamScanner.pdf');
      expect(restored.sourceText, 'DATE 29/07/2026');
      expect(restored.documentDate, DateTime(2026, 7, 29));
      expect(restored.createdAt, created);
    },
  );

  test('older drafts default all signature positions to visible', () {
    const legacy =
        '{"id":"old","title":"Legacy","fileName":"legacy",'
        '"lines":[],"leftStamp":"Left","rightStamp":"Right",'
        '"customStamps":["Third"]}';

    final restored = Quotation.decode(legacy);

    expect(restored.showStampBlocks, isTrue);
    expect(restored.showLeftStamp, isTrue);
    expect(restored.showRightStamp, isTrue);
    expect(restored.customStampIsVisible(0), isTrue);
  });
}
