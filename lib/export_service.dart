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
              1: pw.Alignment.centerLeft,
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
                if (quotation.showStampBlocks) ...[
                  pw.SizedBox(height: 52),
                  pw.Wrap(
                    spacing: 30,
                    runSpacing: 32,
                    children: [
                      for (final label in [
                        quotation.leftStamp,
                        quotation.rightStamp,
                        ...quotation.customStamps,
                      ])
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
      [
        'Sr. No.',
        'Description',
        'Quantity',
        'Unit',
        'Rate',
        'Amount',
        'Tax Rate',
        'Sales Tax',
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
      [
        '',
        'Subtotal',
        '',
        '',
        '',
        money(quotation.subtotalMinor),
        '',
        money(quotation.taxMinor),
        money(quotation.grandTotalMinor),
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
    final rows = <List<Object>>[
      ['Municipal Quotation'],
      [quotation.title],
      [],
      [
        'Sr. No.',
        'Description',
        'Quantity',
        'Unit',
        'Rate',
        'Amount',
        'Tax Rate',
        'Sales Tax',
        'Total',
      ],
      for (var i = 0; i < quotation.lines.length; i++)
        [
          i + 1,
          quotation.lines[i].description,
          quantity(quotation.lines[i].quantityMicros),
          quotation.lines[i].unit,
          quotation.lines[i].rateMinor / 100,
          quotation.lines[i].amountMinor / 100,
          quotation.lines[i].taxBasisPoints / 100,
          quotation.lines[i].salesTaxMinor / 100,
          quotation.lines[i].totalMinor / 100,
        ],
      [],
      [
        '',
        'Grand Total',
        '',
        '',
        '',
        '',
        '',
        '',
        quotation.grandTotalMinor / 100,
      ],
    ];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      for (
        var columnIndex = 0;
        columnIndex < rows[rowIndex].length;
        columnIndex++
      ) {
        final cell = sheet.getRangeByIndex(rowIndex + 1, columnIndex + 1);
        final value = rows[rowIndex][columnIndex];
        if (value is num) {
          cell.setNumber(value.toDouble());
        } else {
          cell.setText(value.toString());
        }
      }
    }
    sheet.getRangeByName('B1:B${rows.length}').columnWidth = 48;
    sheet.getRangeByName('A4:I4').cellStyle.bold = true;
    sheet.getRangeByName('E5:I${rows.length}').numberFormat = '#,##0.00';
    final bytes = book.saveAsStream();
    book.dispose();
    return Uint8List.fromList(bytes);
  }

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
