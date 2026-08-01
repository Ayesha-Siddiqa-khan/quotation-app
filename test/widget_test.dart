import 'package:flutter_test/flutter_test.dart';
import 'package:municipal_quotation_builder/main.dart';

void main() {
  testWidgets('shows the municipal quotation workspace', (tester) async {
    await tester.pumpWidget(const MunicipalQuotationApp());
    await tester.pump();

    expect(find.text('Municipal Quotation Builder'), findsOneWidget);
    expect(find.text('Quotation workspace'), findsOneWidget);
    expect(find.text('Download PDF'), findsOneWidget);
  });
}
