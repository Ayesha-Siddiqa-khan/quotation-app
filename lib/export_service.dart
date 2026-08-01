import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xls;

import 'quotation.dart';

class ExportService {
  final NumberFormat _money = NumberFormat('#,##0.00', 'en_PK');
  final NumberFormat _pdfMoney = NumberFormat('#,##0', 'en_PK');

  String money(int minor) => _money.format(minor / 100);
  String quantity(int micros) {
    final value = micros / 1000000;
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  Future<Uint8List> pdf(Quotation quotation) async {
    final document = pw.Document(
      title: quotation.title,
      author: 'Municipal Committee Chishtian',
      subject: 'Municipal Quotation',
    );
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 10,
      color: PdfColors.white,
    );
    final bodyStyle = const pw.TextStyle(fontSize: 12);
    String pdfMoney(int minor) => _pdfMoney.format(minor / 100);
    final visibleStamps = _visibleStampLabels(quotation);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(39.7, 42.5, 39.7, 39.7),
        maxPages: 100,
        build: (_) => [
          pw.Text(
            quotation.title.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Sr.',
              'Description',
              'Qty',
              'Unit',
              'Rate',
              'Amount',
              'S. Tax',
              'Total',
            ],
            data: [
              for (var i = 0; i < quotation.lines.length; i++)
                [
                  '${i + 1}',
                  quotation.lines[i].description,
                  quantity(quotation.lines[i].quantityMicros),
                  quotation.lines[i].unit,
                  pdfMoney(quotation.lines[i].rateMinor),
                  pdfMoney(quotation.lines[i].amountMinor),
                  pdfMoney(quotation.lines[i].salesTaxMinor),
                  pdfMoney(quotation.lines[i].totalMinor),
                ],
            ],
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 8,
            ),
            headerPadding: const pw.EdgeInsets.symmetric(
              horizontal: 3,
              vertical: 7,
            ),
            headerStyle: headerStyle,
            cellStyle: bodyStyle,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xffeeeeee),
            ),
            border: pw.TableBorder.all(color: PdfColors.black, width: .7),
            columnWidths: const {
              0: pw.FlexColumnWidth(.55),
              1: pw.FlexColumnWidth(3.1),
              2: pw.FlexColumnWidth(.65),
              3: pw.FlexColumnWidth(.65),
              4: pw.FlexColumnWidth(1.1),
              5: pw.FlexColumnWidth(1.2),
              6: pw.FlexColumnWidth(1.05),
              7: pw.FlexColumnWidth(1.2),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
            },
            headerAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.center,
              4: pw.Alignment.center,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
              7: pw.Alignment.center,
            },
          ),
          pw.SizedBox(height: 10),
          pw.Inseparable(
            child: pw.Column(
              children: [
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Container(
                    width: 260,
                    child: pw.Column(
                      children: [
                        _totalRow(
                          'Subtotal',
                          pdfMoney(quotation.subtotalMinor),
                        ),
                        _totalRow('Sales Tax', pdfMoney(quotation.taxMinor)),
                        pw.Divider(height: 4),
                        _totalRow(
                          'Grand Total',
                          pdfMoney(quotation.grandTotalMinor),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                if (quotation.showStampBlocks && visibleStamps.isNotEmpty) ...[
                  pw.SizedBox(height: 52),
                  pw.Wrap(
                    spacing: 30,
                    runSpacing: 32,
                    children: [
                      for (final label in visibleStamps)
                        pw.SizedBox(width: 210, child: _stamp(label)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ),
    );
    return document.save();
  }

  pw.Widget _totalRow(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: bold ? pw.FontWeight.bold : null,
              ),
            ),
            pw.Text(
              'PKR $value',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: bold ? pw.FontWeight.bold : null,
              ),
            ),
          ],
        ),
      );

  pw.Widget _stamp(String label) => pw.Column(
    children: [
      pw.Container(height: 1, color: PdfColors.grey700),
      pw.SizedBox(height: 5),
      pw.Text(
        label,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        'Municipal Committee - Chishtian',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    ],
  );

  Uint8List csv(Quotation quotation) {
    String cell(Object value) => '"${value.toString().replaceAll('"', '""')}"';
    final rows = <List<Object>>[
      [quotation.title.toUpperCase(), '', '', '', '', '', '', '', ''],
      ['', '', '', '', '', '', '', '', ''],
      [
        'Sr.',
        'Description',
        'Qty',
        'Unit',
        'Rate',
        'Amount',
        'Tax %',
        'S. Tax',
        'Total',
      ],
      for (var i = 0; i < quotation.lines.length; i++)
        [
          i + 1,
          quotation.lines[i].description,
          quantity(quotation.lines[i].quantityMicros),
          quotation.lines[i].unit,
          money(quotation.lines[i].rateMinor),
          money(quotation.lines[i].amountMinor),
          '${quotation.lines[i].taxBasisPoints / 100}%',
          money(quotation.lines[i].salesTaxMinor),
          money(quotation.lines[i].totalMinor),
        ],
      ['', '', '', '', '', '', '', '', ''],
      ['', '', '', '', '', '', '', 'Subtotal', money(quotation.subtotalMinor)],
      ['', '', '', '', '', '', '', 'Sales Tax', money(quotation.taxMinor)],
      [
        '',
        '',
        '',
        '',
        '',
        '',
        '',
        'Grand Total',
        money(quotation.grandTotalMinor),
      ],
      if (quotation.showStampBlocks &&
          _visibleStampLabels(quotation).isNotEmpty) ...[
        ['', '', '', '', '', '', '', '', ''],
        for (final stamp in _visibleStampLabels(quotation))
          [
            '',
            stamp,
            'Municipal Committee - Chishtian',
            '',
            '',
            '',
            '',
            '',
            '',
          ],
      ],
    ];
    return Uint8List.fromList(
      utf8.encode(
        '\ufeff${rows.map((row) => row.map(cell).join(',')).join('\r\n')}',
      ),
    );
  }

  Uint8List excel(Quotation quotation) {
    final book = xls.Workbook();
    final sheet = book.worksheets[0];
    sheet.name = 'Quotation';
    final title = sheet.getRangeByName('A1:I2');
    title.merge();
    title.setText(quotation.title.toUpperCase());
    title.cellStyle
      ..bold = true
      ..fontSize = 14
      ..hAlign = xls.HAlignType.center
      ..vAlign = xls.VAlignType.center
      ..wrapText = true;
    title.rowHeight = 24;

    const headings = [
      'Sr.',
      'Description',
      'Qty',
      'Unit',
      'Rate',
      'Amount',
      'Tax %',
      'S. Tax',
      'Total',
    ];
    for (var column = 0; column < headings.length; column++) {
      sheet.getRangeByIndex(4, column + 1).setText(headings[column]);
    }
    final header = sheet.getRangeByName('A4:I4');
    header.cellStyle
      ..bold = true
      ..fontColor = '#FFFFFF'
      ..backColor = '#000000'
      ..hAlign = xls.HAlignType.center
      ..vAlign = xls.VAlignType.center
      ..borders.all.lineStyle = xls.LineStyle.thin;
    header.rowHeight = 25;

    for (var index = 0; index < quotation.lines.length; index++) {
      final row = index + 5;
      final line = quotation.lines[index];
      sheet.getRangeByIndex(row, 1).setNumber((index + 1).toDouble());
      sheet.getRangeByIndex(row, 2).setText(line.description);
      sheet.getRangeByIndex(row, 3).setNumber(line.quantityMicros / 1000000);
      sheet.getRangeByIndex(row, 4).setText(line.unit);
      sheet.getRangeByIndex(row, 5).setNumber(line.rateMinor / 100);
      sheet.getRangeByIndex(row, 6).formula = '=C$row*E$row';
      sheet.getRangeByIndex(row, 7).setNumber(line.taxBasisPoints / 10000);
      sheet.getRangeByIndex(row, 8).formula = '=F$row*G$row';
      sheet.getRangeByIndex(row, 9).formula = '=F$row+H$row';
      final itemRange = sheet.getRangeByName('A$row:I$row');
      itemRange.cellStyle
        ..hAlign = xls.HAlignType.center
        ..vAlign = xls.VAlignType.center
        ..wrapText = true
        ..borders.all.lineStyle = xls.LineStyle.thin;
      sheet.getRangeByIndex(row, 2).cellStyle.hAlign = xls.HAlignType.left;
      sheet.getRangeByName('E$row:F$row').numberFormat = '#,##0.00';
      sheet.getRangeByIndex(row, 7).numberFormat = '0.00%';
      sheet.getRangeByName('H$row:I$row').numberFormat = '#,##0.00';
      itemRange.rowHeight = 30;
    }

    final firstItemRow = 5;
    final lastItemRow = quotation.lines.length + 4;
    final subtotalRow = lastItemRow + 2;
    final taxRow = subtotalRow + 1;
    final grandRow = taxRow + 1;
    sheet.getRangeByIndex(subtotalRow, 8).setText('Subtotal');
    sheet.getRangeByIndex(subtotalRow, 9).formula = quotation.lines.isEmpty
        ? '=0'
        : '=SUM(F$firstItemRow:F$lastItemRow)';
    sheet.getRangeByIndex(taxRow, 8).setText('Sales Tax');
    sheet.getRangeByIndex(taxRow, 9).formula = quotation.lines.isEmpty
        ? '=0'
        : '=SUM(H$firstItemRow:H$lastItemRow)';
    sheet.getRangeByIndex(grandRow, 8).setText('Grand Total');
    sheet.getRangeByIndex(grandRow, 9).formula = '=I$subtotalRow+I$taxRow';
    final totals = sheet.getRangeByName('H$subtotalRow:I$grandRow');
    totals.cellStyle
      ..fontSize = 12
      ..vAlign = xls.VAlignType.center;
    sheet.getRangeByName('I$subtotalRow:I$grandRow').numberFormat =
        '"PKR "#,##0.00';
    final grand = sheet.getRangeByName('H$grandRow:I$grandRow');
    grand.cellStyle
      ..bold = true
      ..borders.top.lineStyle = xls.LineStyle.thin;

    if (quotation.showStampBlocks) {
      final stamps = _visibleStampLabels(quotation);
      for (var index = 0; index < stamps.length; index++) {
        final stampRow = grandRow + 4 + (index ~/ 3) * 4;
        final startColumn = 1 + (index % 3) * 3;
        final endColumn = startColumn + 2;
        final stampRange = sheet.getRangeByIndex(
          stampRow,
          startColumn,
          stampRow + 2,
          endColumn,
        );
        stampRange.merge();
        stampRange.setText('${stamps[index]}\nMunicipal Committee - Chishtian');
        stampRange.cellStyle
          ..bold = true
          ..hAlign = xls.HAlignType.center
          ..vAlign = xls.VAlignType.center
          ..wrapText = true
          ..borders.top.lineStyle = xls.LineStyle.thin;
      }
    }

    sheet.getRangeByName('A1:A$grandRow').columnWidth = 7;
    sheet.getRangeByName('B1:B$grandRow').columnWidth = 42;
    sheet.getRangeByName('C1:D$grandRow').columnWidth = 10;
    sheet.getRangeByName('E1:I$grandRow').columnWidth = 14;
    sheet.pageSetup.fitToPagesWide = 1;
    sheet.pageSetup.fitToPagesTall = 0;
    final bytes = book.saveAsStream();
    book.dispose();
    return Uint8List.fromList(bytes);
  }

  List<String> _visibleStampLabels(Quotation quotation) => [
    if (quotation.showLeftStamp && quotation.leftStamp.trim().isNotEmpty)
      quotation.leftStamp.trim(),
    if (quotation.showRightStamp && quotation.rightStamp.trim().isNotEmpty)
      quotation.rightStamp.trim(),
    for (var index = 0; index < quotation.customStamps.length; index++)
      if (quotation.customStampIsVisible(index) &&
          quotation.customStamps[index].trim().isNotEmpty)
        quotation.customStamps[index].trim(),
  ];

  Future<void> printPdf(Quotation quotation) async {
    final bytes = await pdf(quotation);
    await Printing.layoutPdf(
      name: '${quotation.fileName}.pdf',
      onLayout: (_) async => bytes,
    );
  }

  Future<void> download(String fileName, Uint8List bytes) async {
    await FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
  }

  Future<void> share(String fileName, Uint8List bytes, String mimeType) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'Municipal Quotation',
        subject: 'Municipal Quotation',
        text: 'Municipal quotation prepared by Municipal Committee Chishtian.',
        files: [XFile.fromData(bytes, mimeType: mimeType)],
        fileNameOverrides: [fileName],
      ),
    );
  }
}
