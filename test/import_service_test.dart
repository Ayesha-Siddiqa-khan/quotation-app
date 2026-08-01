import 'package:flutter_test/flutter_test.dart';
import 'package:municipal_quotation_builder/import_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('spatial OCR reconstructs all five rows from the supplied table layout', () {
    RecognizedSourceLine line(
      String text,
      double x,
      double y, [
      double width = 60,
      double height = 20,
    ]) => RecognizedSourceLine(
      text: text,
      left: x,
      top: y,
      width: width,
      height: height,
    );

    final result = ImportService().parseRecognizedLines([
      line('Description of item', 307, 566, 197),
      line('Qty', 610, 566, 36),
      line('Unit', 700, 566, 42),
      line('Rate', 796, 566, 45),
      line('Amount', 899, 566, 85),
      line('S.Tax', 1022, 566, 54),
      line('Total', 1132, 566, 51),
      line('REPAIR/REWINDING OF', 251, 598, 264),
      line('MOTOR 25HP AT CITY', 245, 633, 243),
      line('WATER WORKS TANKI NO. 2', 243, 666, 318),
      line('SET NO. 1 UNDER', 243, 700, 195),
      line('RISDICTION MC', 270, 733, 173),
      line('CHISHTIAN', 244, 767, 120),
      line('Copper Wire Modren', 245, 796, 231),
      line('II Kg', 654, 797, 60),
      line('6200', 820, 797, 54),
      line('68200', 928, 796, 68),
      line('80476', 1150, 795, 67),
      line('Warnish Paper & Cotton', 245, 829, 264),
      line('1 No', 668, 830, 50),
      line('9500', 820, 829, 53),
      line('9500', 942, 829, 54),
      line('11210', 1151, 828, 67),
      line('Bearing NTN 6308', 246, 863, 194),
      line('1 No', 668, 862, 50),
      line('12000', 807, 862, 66),
      line('12000', 929, 862, 67),
      line('14160', 1151, 862, 67),
      line('Bearin NTN 6311', 246, 896, 194),
      line('1 No', 668, 895, 50),
      line('13000', 807, 895, 66),
      line('13000', 929, 895, 67),
      line('15340', 1152, 895, 66),
      line('TOTAL:-', 476, 928, 90),
      line('Rickshaw Fare For Motor', 246, 959, 270),
      line('Repair Trasport From Site to', 246, 993, 306),
      line('Worksho Both Sides', 246, 1025, 231),
      line('2 Job', 667, 1024, 56),
      line('500', 833, 1027, 41),
      line('1000', 943, 1027, 53),
      line('1160', 1165, 1028, 53),
      line('DEDUCTION OF TAXES', 283, 1123, 245),
    ]);

    expect(
      result.title,
      'Repair / Rewinding of Motor 25HP at City Water Works Tanki No. 2 Set No. 1 MC Chishtian',
    );
    expect(result.lines.map((line) => line.description), [
      'Copper Wire Modern',
      'Varnish Paper & Cotton',
      'Bearing NTN 6308',
      'Bearing NTN 6311',
      'Rickshaw Fare for Motor Repair Transport from Site to Workshop Both Sides',
    ]);
    expect(result.lines.map((line) => line.quantityMicros), [
      11000000,
      1000000,
      1000000,
      1000000,
      2000000,
    ]);
    expect(result.lines.last.taxBasisPoints, 1600);
  });

  test('multi-page PDF is returned as separate editable quotations', () async {
    final document = pw.Document();
    for (final title in const [
      'REPAIR OF MOTOR AT TANKI NO. 1',
      'REPAIR OF WATER PUMP AT TANKI NO. 2',
    ]) {
      document.addPage(
        pw.Page(
          build: (_) => pw.Text(
            '$title\nDescription Qty Unit Rate Amount S.Tax Total\nBearing 1 No 1000 1000 180 1180',
          ),
        ),
      );
    }

    final quotations = await ImportService().quotationsFromPdf(
      await document.save(),
    );

    expect(quotations, hasLength(2));
    expect(quotations.first.rawText.replaceAll(' ', ''), contains('TANKINO.1'));
    expect(quotations.last.rawText.replaceAll(' ', ''), contains('TANKINO.2'));
  });

  test('fuzzy scanned headers still extract a single-item quotation', () {
    RecognizedSourceLine line(
      String text,
      double x,
      double y, [
      double width = 55,
    ]) => RecognizedSourceLine(
      text: text,
      left: x,
      top: y,
      width: width,
      height: 18,
    );

    final result = ImportService().parseRecognizedLines([
      line('Description of ltem', 100, 20),
      line('Oty Unlt', 320, 20, 130),
      line('R4te Am0unt', 470, 20, 170),
      line('5.Tu', 660, 20),
      line('PURCHASE OF SALUCE VALVE 8 AT CITY WATER WORKS', 100, 55),
      line('Saluce Valve 8', 100, 100),
      line('1', 320, 100),
      line('No', 390, 100),
      line('58790', 470, 100),
      line('58790', 560, 100),
      line('10582', 660, 100),
      line('69372', 750, 100),
      line('DEDUCTION OF TAXES', 100, 145),
      line('HEAD OFFICE: HOUSE NO.92 BAHWALNAGAR', 100, 220),
    ]);

    expect(result.lines, hasLength(1));
    expect(result.lines.single.description, 'Sluice Valve 8');
    expect(result.title, contains('Purchase of Sluice Valve 8'));
    expect(result.title.toLowerCase(), isNot(contains('head office')));
  });
}
