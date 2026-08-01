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
}
