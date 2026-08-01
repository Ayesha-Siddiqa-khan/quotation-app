import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_ocr/platform_ocr.dart' as native_ocr;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import 'quotation.dart';

enum SourceKind { digitalPdf, scannedPdf, mixedPdf, image }

class ImportResult {
  const ImportResult({
    required this.kind,
    required this.title,
    required this.lines,
    required this.warning,
    required this.rawText,
  });

  final SourceKind kind;
  final String title;
  final List<QuotationLine> lines;
  final String warning;
  final String rawText;
}

class RecognizedSourceLine {
  const RecognizedSourceLine({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
}

class ImportService {
  /// Repairs common word fragmentation and spelling errors produced by OCR.
  /// This is also used when an older imported record is reopened.
  String cleanImportedDescription(String value) => _normaliseDescription(value);

  /// Repairs and formats a work title extracted from a scanned source.
  String cleanImportedTitle(String value) => _formatTitle(value);

  /// Finds a document date in full-page PDF or image OCR text.
  DateTime? extractDocumentDate(String text) {
    const component = r'[0-9OoIl]{1,2}';
    const year = r'[0-9OoIl]{2,4}';
    const separator = r'\s*[/\.\-|]\s*';
    final labelled = RegExp(
      '(?:date|dated)\\s*[:\\-]?\\s*($component)$separator($component)$separator($year)',
      caseSensitive: false,
    ).firstMatch(text);
    final generic = RegExp(
      '\\b($component)$separator($component)$separator($year)\\b',
      caseSensitive: false,
    ).firstMatch(text);
    final match = labelled ?? generic;
    if (match == null) return null;

    int number(String value) => int.parse(
      value.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[Il]'), '1'),
    );

    final first = number(match.group(1)!);
    final second = number(match.group(2)!);
    var parsedYear = number(match.group(3)!);
    if (parsedYear < 100) parsedYear += 2000;
    final dayFirst = DateTime(parsedYear, second, first);
    if (dayFirst.day == first &&
        dayFirst.month == second &&
        dayFirst.year == parsedYear) {
      return dayFirst;
    }
    final monthFirst = DateTime(parsedYear, first, second);
    return monthFirst.day == second &&
            monthFirst.month == first &&
            monthFirst.year == parsedYear
        ? monthFirst
        : null;
  }

  bool get _supportsOcr =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  ImportResult parseRecognizedLines(List<RecognizedSourceLine> lines) {
    final spatial = lines
        .map(
          (line) => _SpatialLine(
            line.text,
            line.left,
            line.top,
            line.width,
            line.height,
          ),
        )
        .toList();
    final parsed = _parseSpatial(spatial);
    return ImportResult(
      kind: SourceKind.image,
      title: parsed.title,
      lines: parsed.lines,
      warning: 'Review extracted fields before export.',
      rawText: lines.map((line) => line.text).join('\n'),
    );
  }

  Future<ImportResult> fromPdf(Uint8List bytes) async {
    final pages = await quotationsFromPdf(bytes);
    if (pages.isEmpty) {
      return const ImportResult(
        kind: SourceKind.scannedPdf,
        title: '',
        lines: [],
        warning: 'No readable quotation pages were found.',
        rawText: '',
      );
    }
    final combined = _combine([
      for (final page in pages) _Parsed(page.title, page.lines),
    ]);
    return ImportResult(
      kind: pages.first.kind,
      title: combined.title,
      lines: combined.lines,
      warning: pages.length == 1
          ? pages.first.warning
          : '${pages.length} quotation pages were detected. Review each quotation separately.',
      rawText: pages.map((page) => page.rawText).join('\n'),
    );
  }

  Future<List<ImportResult>> quotationsFromPdf(Uint8List bytes) async {
    final document = sf.PdfDocument(inputBytes: bytes);
    final pages = document.pages.count;
    final extractor = sf.PdfTextExtractor(document);
    final pageTexts = <String>[];
    for (var i = 0; i < pages; i++) {
      pageTexts.add(
        extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
          layoutText: true,
        ),
      );
    }
    document.dispose();

    final digitalPages = pageTexts
        .where((page) => page.trim().length > 20)
        .length;
    final kind = digitalPages == 0
        ? SourceKind.scannedPdf
        : digitalPages < pages
        ? SourceKind.mixedPdf
        : SourceKind.digitalPdf;
    final parsedPages = List<_Parsed?>.filled(pages, null);
    var ocrPages = 0;

    for (var i = 0; i < pageTexts.length; i++) {
      if (pageTexts[i].trim().length > 20) {
        parsedPages[i] = _parseText(pageTexts[i]);
        continue;
      }
      if (!_supportsOcr) continue;
      try {
        final ocr = await _ocrPdfPage(bytes, i);
        if (ocr.text.trim().isNotEmpty) {
          pageTexts[i] = ocr.text;
          parsedPages[i] = _parseSpatial(ocr.lines);
          ocrPages++;
        }
      } on Object {
        // The unreadable page is reported for manual review below.
      }
    }

    final parsed = _combine(parsedPages.whereType<_Parsed>().toList());
    final warning = switch (kind) {
      SourceKind.scannedPdf =>
        ocrPages > 0
            ? 'OCR read $ocrPages scanned page(s) and found ${parsed.lines.length} item row(s). Verify every field before export.'
            : 'This PDF is image-only and could not be read automatically. Enter the fields manually or import a clearer scan.',
      SourceKind.mixedPdf =>
        ocrPages > 0
            ? 'Digital text and OCR data were combined from this mixed PDF. Verify every extracted field.'
            : 'Text was extracted from digital pages. Unreadable image-only pages are marked for review.',
      _ when parsed.lines.isEmpty =>
        'Text was found, but no reliable item rows were detected. Check the title and add missing lines manually.',
      _ => 'Review the extracted fields before export.',
    };
    return [
      for (var i = 0; i < pages; i++)
        ImportResult(
          kind: kind,
          title: parsedPages[i]?.title ?? '',
          lines: parsedPages[i]?.lines ?? <QuotationLine>[],
          warning: pages == 1
              ? warning
              : 'Quotation ${i + 1} of $pages. ${parsedPages[i] == null ? 'This page could not be read automatically; enter it manually.' : 'Review the extracted fields before moving to the next quotation.'}',
          rawText: pageTexts[i],
        ),
    ];
  }

  Future<ImportResult> fromImage(String? path) async {
    if (!_supportsOcr || path == null) {
      return const ImportResult(
        kind: SourceKind.image,
        title: '',
        lines: [],
        warning:
            'Image OCR is unavailable on this platform. Enter the fields manually.',
        rawText: '',
      );
    }
    final ocr = await _ocrImage(path);
    final parsed = _parseSpatial(ocr.lines);
    return ImportResult(
      kind: SourceKind.image,
      title: parsed.title,
      lines: parsed.lines,
      warning: parsed.lines.isEmpty
          ? 'OCR completed, but no reliable rows were found. Review the image and enter missing fields.'
          : 'Image OCR found ${parsed.lines.length} item row(s). Verify every field before export.',
      rawText: ocr.text,
    );
  }

  Future<_OcrData> _ocrPdfPage(Uint8List bytes, int pageIndex) async {
    await for (final page in Printing.raster(
      bytes,
      pages: [pageIndex],
      dpi: 160,
    )) {
      return _ocrPng(await page.toPng(), 'pdf_$pageIndex');
    }
    return const _OcrData('', []);
  }

  Future<_OcrData> _ocrPng(Uint8List bytes, String suffix) async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await native_ocr.recognizeText(
        native_ocr.OcrSource.memory(bytes),
      );
      return _OcrData(
        result.text,
        result.lines
            .map(
              (line) => _SpatialLine(
                line.text,
                line.boundingBox.left,
                line.boundingBox.top,
                line.boundingBox.width,
                line.boundingBox.height,
              ),
            )
            .toList(),
      );
    }
    final temporary = await getTemporaryDirectory();
    final file = File(
      '${temporary.path}${Platform.pathSeparator}quotation_ocr_$suffix.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    try {
      return _ocrImage(file.path);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<_OcrData> _ocrImage(String path) async {
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final result = await native_ocr.recognizeText(
        native_ocr.OcrSource.file(File(path)),
      );
      return _OcrData(
        result.text,
        result.lines
            .map(
              (line) => _SpatialLine(
                line.text,
                line.boundingBox.left,
                line.boundingBox.top,
                line.boundingBox.width,
                line.boundingBox.height,
              ),
            )
            .toList(),
      );
    }
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      final lines = <_SpatialLine>[];
      for (final block in result.blocks) {
        for (final line in block.lines) {
          lines.add(
            _SpatialLine(
              line.text,
              line.boundingBox.left,
              line.boundingBox.top,
              line.boundingBox.width,
              line.boundingBox.height,
            ),
          );
        }
      }
      return _OcrData(result.text, lines);
    } finally {
      await recognizer.close();
    }
  }

  _Parsed _parseSpatial(List<_SpatialLine> sourceLines) {
    final lines = sourceLines
        .map((line) => line.copyWith(text: _normaliseOcr(line.text)))
        .where((line) => line.text.trim().isNotEmpty)
        .toList();
    _SpatialLine? findHeader(RegExp pattern) {
      final matches = <(_SpatialLine, RegExpMatch)>[];
      for (final line in lines) {
        final match = pattern.firstMatch(line.text);
        if (match != null) matches.add((line, match));
      }
      if (matches.isEmpty) return null;
      matches.sort((a, b) => a.$1.centerY.compareTo(b.$1.centerY));
      final (line, match) = matches.first;
      if (match.start == 0 && match.end == line.text.length) return line;
      final characterWidth = line.width / line.text.length;
      return _SpatialLine(
        match.group(0)!,
        line.left + match.start * characterWidth,
        line.top,
        (match.end - match.start) * characterWidth,
        line.height,
      );
    }

    final descriptionHeader = findHeader(
      RegExp(r'\bdescr[a-z]*\s*(?:of\s*)?[i1l|]tem\b', caseSensitive: false),
    );
    _SpatialLine? findColumnHeader(RegExp pattern) {
      final header = findHeader(pattern);
      if (header == null || descriptionHeader == null) return null;
      final bandTolerance = descriptionHeader.height * 3 < 45
          ? 45.0
          : descriptionHeader.height * 3;
      return (header.centerY - descriptionHeader.centerY).abs() <= bandTolerance
          ? header
          : null;
    }

    final qtyHeader = findColumnHeader(
      RegExp(r'\b[q0oa][tli1][yv]\b', caseSensitive: false),
    );
    final unitHeader = findColumnHeader(
      RegExp(r'\bun[i1l|][t7]\b', caseSensitive: false),
    );
    final rateHeader = findColumnHeader(
      RegExp(r'\br[a4o]te\b', caseSensitive: false),
    );
    final amountHeader = findColumnHeader(
      RegExp(r'\ba[mrn][o0]unt\b', caseSensitive: false),
    );
    var taxHeader = findColumnHeader(
      RegExp(r'\b[s5][.,\s]*(?:tax|tu)\b', caseSensitive: false),
    );
    var totalHeader = findColumnHeader(
      RegExp(r'\bt[o0]ta[l1|]\b', caseSensitive: false),
    );
    if (taxHeader == null && amountHeader != null && totalHeader != null) {
      taxHeader = _SpatialLine(
        'S.Tax',
        (amountHeader.centerX + totalHeader.centerX) / 2,
        amountHeader.top,
        0,
        amountHeader.height,
      );
    }
    if (totalHeader == null && amountHeader != null && taxHeader != null) {
      totalHeader = _SpatialLine(
        'Total',
        taxHeader.centerX + (taxHeader.centerX - amountHeader.centerX),
        taxHeader.top,
        0,
        taxHeader.height,
      );
    }
    if (descriptionHeader == null ||
        qtyHeader == null ||
        unitHeader == null ||
        rateHeader == null ||
        amountHeader == null ||
        taxHeader == null ||
        totalHeader == null) {
      return _parseText(lines.map((line) => line.text).join('\n'));
    }

    final deduction = findHeader(
      RegExp(r'deduction\s+of\s+taxes', caseSensitive: false),
    );
    final tableBottom = deduction?.centerY ?? double.infinity;
    final centers = [
      descriptionHeader.centerX,
      qtyHeader.centerX,
      unitHeader.centerX,
      rateHeader.centerX,
      amountHeader.centerX,
      taxHeader.centerX,
      totalHeader.centerX,
    ];
    bool inColumn(_SpatialLine line, int column) {
      final left = column == 0
          ? double.negativeInfinity
          : (centers[column - 1] + centers[column]) / 2;
      final right = column == centers.length - 1
          ? double.infinity
          : (centers[column] + centers[column + 1]) / 2;
      return line.centerX >= left && line.centerX < right;
    }

    final numeric = RegExp(r'^\d+(?:\.\d+)?$');
    final rateLines =
        lines
            .where(
              (line) =>
                  line.centerY > rateHeader.centerY + 15 &&
                  line.centerY < tableBottom &&
                  inColumn(line, 3) &&
                  numeric.hasMatch(line.text.replaceAll(',', '')),
            )
            .toList()
          ..sort((a, b) => a.centerY.compareTo(b.centerY));
    final extracted = <QuotationLine>[];
    var previousRowY = descriptionHeader.centerY;

    for (var i = 0; i < rateLines.length; i++) {
      final rateLine = rateLines[i];
      final rowTolerance = rateLine.height * 1.25 < 24
          ? 24.0
          : rateLine.height * 1.25;
      _SpatialLine? nearestInColumn(int column) {
        final candidates =
            lines
                .where(
                  (line) =>
                      inColumn(line, column) &&
                      numeric.hasMatch(line.text.replaceAll(',', '')) &&
                      (line.centerY - rateLine.centerY).abs() < rowTolerance,
                )
                .toList()
              ..sort(
                (a, b) => (a.centerY - rateLine.centerY).abs().compareTo(
                  (b.centerY - rateLine.centerY).abs(),
                ),
              );
        return candidates.isEmpty ? null : candidates.first;
      }

      final amountLine = nearestInColumn(4);
      final totalLine = nearestInColumn(6);
      if (amountLine == null || totalLine == null) continue;
      final rateMinor = parseMoneyMinor(rateLine.text);
      final amountMinor = parseMoneyMinor(amountLine.text);
      if (rateMinor <= 0 || amountMinor <= 0) continue;

      final gap = rateLine.centerY - previousRowY;
      final descriptionStart = i == 0
          ? rateLine.centerY - rowTolerance
          : gap > 70
          ? previousRowY + 18
          : rateLine.centerY - rowTolerance;
      final descriptionParts =
          lines
              .where(
                (line) =>
                    inColumn(line, 0) &&
                    line.centerY >= descriptionStart &&
                    line.centerY <= rateLine.centerY + rowTolerance &&
                    !_isIgnoredRow(line.text),
              )
              .toList()
            ..sort((a, b) => a.centerY.compareTo(b.centerY));
      final description = _normaliseDescription(
        descriptionParts.map((line) => line.text).join(' '),
      );
      if (description.isEmpty || _looksLikeHeader(description)) continue;

      final quantityMicros =
          ((amountMinor * 1000000) + (rateMinor ~/ 2)) ~/ rateMinor;
      final unitCandidates = lines.where(
        (line) =>
            line.centerX > (centers[0] + centers[1]) / 2 &&
            line.centerX < (centers[2] + centers[3]) / 2 &&
            (line.centerY - rateLine.centerY).abs() < rowTolerance,
      );
      var unit = 'No';
      for (final candidate in unitCandidates) {
        final match = RegExp(
          r'\b(Kg|No|Job)\b',
          caseSensitive: false,
        ).firstMatch(candidate.text);
        if (match != null) {
          unit = _capitalise(match.group(1)!);
          break;
        }
      }
      final category = _category(description);
      extracted.add(
        QuotationLine(
          id: 'import-${DateTime.now().microsecondsSinceEpoch}-$i',
          description: description,
          quantityMicros: quantityMicros,
          unit: unit,
          rateMinor: rateMinor,
          taxCategory: category,
          taxBasisPoints: category == TaxCategory.labour ? 1600 : 1800,
        ),
      );
      previousRowY = rateLine.centerY;
    }

    var title = '';
    if (rateLines.isNotEmpty) {
      final titleLines =
          lines
              .where(
                (line) =>
                    inColumn(line, 0) &&
                    line.centerY > descriptionHeader.centerY + 18 &&
                    line.centerY < rateLines.first.centerY - 24 &&
                    !_isIgnoredRow(line.text),
              )
              .toList()
            ..sort((a, b) => a.centerY.compareTo(b.centerY));
      title = _formatTitle(titleLines.map((line) => line.text).join(' '));
    }
    return _Parsed(title, extracted);
  }

  _Parsed _parseText(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => _normaliseOcr(line.replaceAll(RegExp(r'\s+'), ' ')))
        .where((line) => line.isNotEmpty)
        .toList();
    final rowPattern = RegExp(
      r'^(?:\d+[.)]?\s+)?(.+?)\s+(\d+(?:\.\d+)?)\s+([A-Za-z.]+)\s+([\d,]+(?:\.\d+)?)(?:\s+[\d,]+(?:\.\d+)?){0,3}\s*$',
    );
    final extracted = <QuotationLine>[];
    var firstRowIndex = lines.length;
    for (var i = 0; i < lines.length; i++) {
      final source = lines[i];
      if (_isIgnoredRow(source)) continue;
      final match = rowPattern.firstMatch(source);
      if (match == null) continue;
      final description = _normaliseDescription(match.group(1)!.trim());
      if (_looksLikeHeader(description)) continue;
      try {
        final category = _category(description);
        extracted.add(
          QuotationLine(
            id: 'import-${DateTime.now().microsecondsSinceEpoch}-$i',
            description: description,
            quantityMicros: parseQuantityMicros(match.group(2)!),
            unit: match.group(3)!.replaceAll('.', ''),
            rateMinor: parseMoneyMinor(match.group(4)!),
            taxCategory: category,
            taxBasisPoints: category == TaxCategory.labour ? 1600 : 1800,
          ),
        );
        if (firstRowIndex == lines.length) firstRowIndex = i;
      } on FormatException {
        // Invalid OCR numbers are held back for manual review.
      }
    }
    final candidates = lines.take(firstRowIndex).where((line) {
      final lower = line.toLowerCase();
      return line.length > 18 &&
          !_looksLikeHeader(line) &&
          !lower.contains('invoice') &&
          !lower.contains('bill no') &&
          !lower.contains('ntn') &&
          !lower.contains('consignee') &&
          !lower.contains('supplier') &&
          !lower.contains('head office') &&
          !lower.contains('sub office') &&
          !lower.contains('branch office') &&
          !lower.contains('contact') &&
          !lower.contains('housing colony') &&
          !lower.contains('bahawalnagar');
    }).toList();
    candidates.sort((a, b) {
      final aWork = RegExp(
        r'\b(repair|purchase|rewinding|work|supply)\b',
        caseSensitive: false,
      ).hasMatch(a);
      final bWork = RegExp(
        r'\b(repair|purchase|rewinding|work|supply)\b',
        caseSensitive: false,
      ).hasMatch(b);
      if (aWork != bWork) return aWork ? -1 : 1;
      return b.length.compareTo(a.length);
    });
    return _Parsed(
      candidates.isEmpty ? '' : _formatTitle(candidates.first),
      extracted,
    );
  }

  _Parsed _combine(List<_Parsed> pages) {
    final lines = <QuotationLine>[];
    var title = '';
    for (final page in pages) {
      if (title.isEmpty && page.title.isNotEmpty) title = page.title;
      lines.addAll(page.lines);
    }
    return _Parsed(title, lines);
  }

  String _normaliseOcr(String value) {
    var cleaned = value
        .replaceAll(RegExp(r'[\u00a0\u2007\u202f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (RegExp(r'^[\dOoIl|,.\s]+$').hasMatch(cleaned)) {
      cleaned = cleaned
          .replaceAll(RegExp(r'[Oo]'), '0')
          .replaceAll(RegExp(r'[Il|]'), '1');
    }
    return cleaned
        .replaceAll(RegExp(r'\bmodren\b', caseSensitive: false), 'Modern')
        .replaceAll(
          RegExp(
            r'\bc[o0][\s._-]*p?[\s._-]*e[\s._-]*r[\s._-]+wire\b',
            caseSensitive: false,
          ),
          'Copper Wire',
        )
        .replaceAll(
          RegExp(r'\bco\s+er\s+wire\b', caseSensitive: false),
          'Copper Wire',
        )
        .replaceAll(
          RegExp(r'\bco\s+r\s+wire\b', caseSensitive: false),
          'Copper Wire',
        )
        .replaceAll(
          RegExp(r'\b(?:warnish|varnsh|varnls[h]?)\b', caseSensitive: false),
          'Varnish',
        )
        .replaceAll(
          RegExp(r'\bpa[\s._-]*p?[\s._-]*e[\s._-]*r\b', caseSensitive: false),
          'Paper',
        )
        .replaceAll(RegExp(r'\bpa\s+r\b', caseSensitive: false), 'Paper')
        .replaceAll(
          RegExp(r'\bream\s*a\s*4\b', caseSensitive: false),
          'Ream A4',
        )
        .replaceAll(
          RegExp(r'\bpaper\s+ream\s+a4\s+7\s*m\b', caseSensitive: false),
          'Paper Ream A4 70 GSM',
        )
        .replaceAll(RegExp(r'\bbearin\b', caseSensitive: false), 'Bearing')
        .replaceAll(RegExp(r'\btrasport\b', caseSensitive: false), 'Transport')
        .replaceAll(RegExp(r'\bworksho\b', caseSensitive: false), 'Workshop')
        .replaceAll(
          RegExp(r'\b(?:tnaky|tnky|tanky)\b', caseSensitive: false),
          'Tanki',
        )
        .replaceAll(
          RegExp(r'\bbod\s+bush\b', caseSensitive: false),
          'Body Bush',
        )
        .replaceAll(
          RegExp(r'\bglane\s+bush\b', caseSensitive: false),
          'Gland Bush',
        )
        .replaceAll(RegExp(r'\bsaluce\b', caseSensitive: false), 'Sluice')
        .replaceAll(RegExp(r'\broooter\b', caseSensitive: false), 'Rotor')
        .replaceAll(RegExp(r'\brooter\b', caseSensitive: false), 'Rotor')
        .replaceAll(
          RegExp(r'\bam\s+meter\b', caseSensitive: false),
          'Amp Meter',
        )
        .replaceAll(RegExp(r'\bcantroll\b', caseSensitive: false), 'Control')
        .replaceAll(
          RegExp(r'\bs\s+indal\s+re\s+air\b', caseSensitive: false),
          'Spindle Repair',
        )
        .replaceAll(RegExp(r'\bpum\b', caseSensitive: false), 'Pump')
        .replaceAll(
          RegExp(
            r'\bf\s*/?\s*w\s+(?:towl|twel+l?|tow?l|t\s*/?\s*well|tube\s*well)\b',
            caseSensitive: false,
          ),
          'F/W Tubewell',
        )
        .replaceAll(
          RegExp(r'\b(?:towl|twel+l?|tow?l)\b', caseSensitive: false),
          'Tubewell',
        )
        .replaceAll(RegExp(r'\b2shp\b', caseSensitive: false), '25HP')
        .replaceAll(RegExp(r'\bno\.?\s*[i|]\b', caseSensitive: false), 'No. 1')
        .replaceAll(RegExp(r'\bchistian\b', caseSensitive: false), 'Chishtian')
        .replaceAll(
          RegExp(r'\bpurchase\s+of\s+stationary\b', caseSensitive: false),
          'Purchase of Stationery',
        )
        .replaceAll(RegExp(r'\bworls\b', caseSensitive: false), 'Works')
        .replaceAll(RegExp(r'\bcricle\b', caseSensitive: false), 'Circle')
        .replaceAll(RegExp(r'\be-bilung\b', caseSensitive: false), 'E-billing')
        .replaceAll(
          RegExp(r'\bat\s+city\s+no\.', caseSensitive: false),
          'at City Tanki No.',
        )
        .replaceAll(
          RegExp(r'\brisdiction\b', caseSensitive: false),
          'Jurisdiction',
        )
        .trim();
  }

  String _normaliseDescription(String value) {
    final cleaned = _normaliseOcr(value).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return '';
    const lowerWords = {'for', 'from', 'to', 'of', 'and'};
    final words = cleaned.split(' ');
    return [
      for (var i = 0; i < words.length; i++)
        i > 0 && lowerWords.contains(words[i].toLowerCase())
            ? words[i].toLowerCase()
            : _capitalise(words[i]),
    ].join(' ').replaceAll('Ntn', 'NTN').replaceAll('Gsm', 'GSM');
  }

  String _formatTitle(String value) {
    final words =
        _normaliseOcr(
              value.replaceAll(
                RegExp(
                  r'\bunder\s+jurisdiction(?:\s+of)?\b',
                  caseSensitive: false,
                ),
                '',
              ),
            )
            .replaceAll('F/W', 'F_W')
            .replaceAll('/', ' / ')
            .replaceAll('F_W', 'F/W')
            .split(RegExp(r'\s+'));
    const lowerWords = {'of', 'at', 'under'};
    return words
        .map((word) {
          final upper = word.toUpperCase();
          if (word == '/') return '/';
          if (RegExp(r'^\d+HP$').hasMatch(upper) ||
              upper == 'MC' ||
              upper == 'F/W') {
            return upper;
          }
          if (lowerWords.contains(word.toLowerCase())) {
            return word.toLowerCase();
          }
          if (upper == 'NO.' || upper == 'NO') return 'No.';
          return _capitalise(word);
        })
        .join(' ')
        .replaceAll(' / ', ' / ')
        .trim();
  }

  String _capitalise(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  bool _isIgnoredRow(String value) => RegExp(
    r'^(total|subtotal|grand total|deduction of taxes|total taxes|net payable)\b',
    caseSensitive: false,
  ).hasMatch(value.trim());

  bool _looksLikeHeader(String value) {
    final lower = value.toLowerCase();
    return lower.contains('description') ||
        (lower.contains('quantity') && lower.contains('rate')) ||
        lower == 'qty';
  }

  TaxCategory _category(String description) {
    final value = description.toLowerCase();
    if (RegExp(
      r'labou?r|repair|service|fare|transport|winding|installation',
    ).hasMatch(value)) {
      return TaxCategory.labour;
    }
    return TaxCategory.material;
  }
}

class _OcrData {
  const _OcrData(this.text, this.lines);
  final String text;
  final List<_SpatialLine> lines;
}

class _SpatialLine {
  const _SpatialLine(this.text, this.left, this.top, this.width, this.height);
  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  _SpatialLine copyWith({String? text}) =>
      _SpatialLine(text ?? this.text, left, top, width, height);
}

class _Parsed {
  const _Parsed(this.title, this.lines);
  final String title;
  final List<QuotationLine> lines;
}
