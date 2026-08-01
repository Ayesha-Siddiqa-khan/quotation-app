import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'export_service.dart';
import 'import_service.dart';
import 'local_database.dart';
import 'quotation.dart';

void main() => runApp(const MunicipalQuotationApp());

class MunicipalQuotationApp extends StatelessWidget {
  const MunicipalQuotationApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xff145c55);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Municipal Quotation Builder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.light,
          surface: const Color(0xfff7f8f4),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xffeef2ed),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
            side: BorderSide(color: Color(0xffdfe6df)),
          ),
        ),
      ),
      home: const QuotationWorkspace(),
    );
  }
}

class QuotationWorkspace extends StatefulWidget {
  const QuotationWorkspace({super.key});

  @override
  State<QuotationWorkspace> createState() => _QuotationWorkspaceState();
}

class _QuotationWorkspaceState extends State<QuotationWorkspace> {
  static const _commonItemSuggestions = <String>[
    'Copper Wire Modern',
    'Varnish Paper & Cotton',
    'Bearing NTN 6308',
    'Bearing NTN 6311',
    'Motor Rewinding and Repair',
    'Pump Repair and Servicing',
    'Transformer Repair and Maintenance',
    'Mechanical Seal for Water Pump',
    'Motor Bearing Replacement',
    'Transformer Oil Replacement',
    'Pump Impeller Replacement',
    'Rickshaw Fare for Motor Repair Transport From Site to Workshop Both Sides',
  ];
  final _export = ExportService();
  final _import = ImportService();
  final _database = LocalQuotationDatabase();
  final _titleController = TextEditingController();
  final _fileController = TextEditingController();
  final _searchController = TextEditingController();
  final Map<String, TextEditingController> _cellControllers = {};
  Timer? _autosave;
  var _busy = false;
  var _saved = true;
  var _sourceMessage = 'No source attached · Manual quotation';
  var _selectedSection = 1;
  var _sourceQuotationIndex = 0;
  var _libraryFilter = 'all';
  var _previewVisible = true;
  var _previewWidth = 660.0;
  var _operationId = 0;
  var _busyMessage = 'Preparing your document…';
  List<StoredQuotation> _libraryRecords = [];
  List<Quotation> _sourceQuotations = [];
  late Quotation _quotation;

  @override
  void initState() {
    super.initState();
    _quotation = _starterQuotation();
    _restore();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _titleController.dispose();
    _fileController.dispose();
    _searchController.dispose();
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Quotation _starterQuotation() => Quotation(
    title: '',
    fileName: 'Municipal Quotation',
    leftStamp: 'Sub Engineer',
    rightStamp: 'Municipal Officer (Infrastructure)',
    lines: [],
  );

  Future<void> _restore() async {
    try {
      final saved = await _database.latest();
      if (saved != null) {
        _repairImportedDescriptions(saved);
        _quotation = saved;
      }
      _previewVisible = (await _database.setting('preview_visible')) != 'false';
      await _refreshLibrary(notify: false);
    } on Object {
      // A database failure leaves manual entry available without losing the UI.
    }
    _syncControllers();
    if (mounted) setState(() {});
  }

  void _syncControllers() {
    _titleController.text = _quotation.title;
    _fileController.text = _quotation.fileName;
  }

  void _changed() {
    _quotation.title = _titleController.text;
    _quotation.fileName = _safeFileName(_fileController.text);
    _quotation.updatedAt = DateTime.now();
    _autosave?.cancel();
    setState(() => _saved = false);
    _autosave = Timer(const Duration(milliseconds: 650), _save);
  }

  Future<void> _save() async {
    await _database.save(_quotation);
    await _refreshLibrary(notify: false);
    if (mounted) setState(() => _saved = true);
  }

  Future<void> _refreshLibrary({bool notify = true}) async {
    final records = await _database.records(query: _searchController.text);
    _libraryRecords = records;
    if (notify && mounted) setState(() {});
  }

  bool _repairImportedDescriptions(Quotation quotation) {
    if (quotation.sourceName.isEmpty) return false;
    var changed = false;
    final oldTitle = quotation.title;
    final cleanedTitle = _import.cleanImportedTitle(oldTitle);
    if (cleanedTitle != oldTitle) {
      quotation.title = cleanedTitle;
      final looksGenerated = quotation.fileName.toLowerCase().startsWith(
        'quotation for ',
      );
      if (looksGenerated) {
        quotation.fileName = _safeFileName(_suggestFileName(cleanedTitle));
      }
      changed = true;
    }
    if (quotation.documentDate == null && quotation.sourceText.isNotEmpty) {
      final detected = _import.extractDocumentDate(quotation.sourceText);
      if (detected != null) {
        quotation.documentDate = detected;
        changed = true;
      }
    }
    for (final line in quotation.lines) {
      final cleaned = _import.cleanImportedDescription(line.description);
      if (cleaned != line.description) {
        line.description = cleaned;
        changed = true;
      }
    }
    return changed;
  }

  String _safeFileName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');
    return safe.isEmpty ? 'municipal_quotation' : safe;
  }

  int _beginOperation(String message) {
    final id = ++_operationId;
    setState(() {
      _busy = true;
      _busyMessage = message;
    });
    return id;
  }

  void _cancelOperation() {
    _operationId++;
    setState(() => _busy = false);
    _notice('The operation was cancelled.');
  }

  Future<void> _pickSource() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final extension = (file.extension ?? '').toLowerCase();
    final operation = _beginOperation('Reading and saving source document…');
    try {
      late List<ImportResult> importedPages;
      if (extension == 'pdf') {
        final bytes = file.bytes;
        if (bytes == null) {
          throw const FormatException('The selected PDF could not be read.');
        }
        importedPages = await _import.quotationsFromPdf(bytes);
      } else {
        importedPages = [await _import.fromImage(file.path)];
      }
      if (operation != _operationId) return;
      if (importedPages.isEmpty) {
        throw const FormatException('No quotation pages were found.');
      }
      _autosave?.cancel();
      final stampTemplate = _quotation;
      _sourceQuotations = [];
      for (var i = 0; i < importedPages.length; i++) {
        if (operation != _operationId) return;
        final imported = importedPages[i];
        final reference = Quotation(
          id: 'reference-${DateTime.now().microsecondsSinceEpoch}-$i',
          title: imported.title.trim(),
          fileName: _suggestFileName(imported.title),
          lines: imported.lines.map((line) => line.copy()).toList(),
          leftStamp: stampTemplate.leftStamp,
          rightStamp: stampTemplate.rightStamp,
          showStampBlocks: stampTemplate.showStampBlocks,
          showLeftStamp: stampTemplate.showLeftStamp,
          showRightStamp: stampTemplate.showRightStamp,
          customStamps: List<String>.from(stampTemplate.customStamps),
          customStampVisibility: List<bool>.from(
            stampTemplate.customStampVisibility,
          ),
          sourceName: file.name,
          sourceText: imported.rawText,
          documentDate: _import.extractDocumentDate(
            '${file.name}\n${imported.rawText}',
          ),
        );
        await _database.saveReference(reference);
        if (operation != _operationId) return;
        final editable = reference.copy(
          id: 'quotation-${DateTime.now().microsecondsSinceEpoch}-$i',
          recordType: QuotationRecordType.draft,
        );
        _sourceQuotations.add(editable);
        await _database.save(editable);
      }
      if (operation != _operationId) return;
      _sourceQuotationIndex = 0;
      _quotation = _sourceQuotations.first;
      _resetCellControllers();
      _sourceMessage =
          '${file.name} · ${_sourceLabel(importedPages.first.kind)}';
      _syncControllers();
      _changed();
      await _refreshLibrary(notify: false);
      if (mounted && operation == _operationId) {
        _notice(
          importedPages.length == 1
              ? importedPages.first.warning
              : '${importedPages.length} separate quotations detected. Review quotation 1, then use Next quotation.',
          warning: true,
        );
      }
    } on Object catch (error) {
      if (mounted && operation == _operationId) {
        _notice(
          'Could not read this source. Try an unlocked PDF or a clear JPG/PNG. $error',
          warning: true,
        );
      }
    } finally {
      if (mounted && operation == _operationId) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickDocumentDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _quotation.documentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null) return;
    setState(() => _quotation.documentDate = selected);
    _changed();
  }

  String _sourceLabel(SourceKind kind) => switch (kind) {
    SourceKind.digitalPdf => 'Digital-text PDF',
    SourceKind.scannedPdf => 'Scanned PDF · review required',
    SourceKind.mixedPdf => 'Mixed PDF · review required',
    SourceKind.image => 'Image OCR',
  };

  Future<void> _newQuotation() async {
    _autosave?.cancel();
    _sourceQuotations = [];
    _sourceQuotationIndex = 0;
    _quotation = Quotation(
      title: '',
      fileName: 'municipal_quotation',
      lines: [],
      leftStamp: 'Sub Engineer',
      rightStamp: 'Municipal Officer (Infrastructure)',
    );
    _sourceMessage = 'No source attached · Manual quotation';
    _resetCellControllers();
    _syncControllers();
    setState(() => _selectedSection = 1);
    _changed();
  }

  Future<void> _saveAsRecord() async {
    _quotation.title = _titleController.text;
    _quotation.fileName = _safeFileName(_fileController.text);
    _quotation.recordType = QuotationRecordType.edited;
    await _database.save(_quotation);
    await _refreshLibrary();
    if (mounted) {
      setState(() => _saved = true);
      _notice('Quotation saved in Edited quotations.');
    }
  }

  Future<void> _showSourceQuotation(int index) async {
    if (index < 0 || index >= _sourceQuotations.length) return;
    _autosave?.cancel();
    _quotation.title = _titleController.text;
    _quotation.fileName = _safeFileName(_fileController.text);
    await _database.save(_quotation);
    if (!mounted) return;
    setState(() {
      _sourceQuotationIndex = index;
      _quotation = _sourceQuotations[index];
      _saved = true;
      _resetCellControllers();
      _syncControllers();
    });
  }

  Future<void> _addOrEditLine([QuotationLine? existing, int? insertAt]) async {
    final learnedSuggestions = await _database.suggestions('');
    if (!mounted) return;
    final suggestions = <String>{
      ...learnedSuggestions,
      ..._commonItemSuggestions,
    }.toList();
    final description = TextEditingController(
      text: existing?.description ?? '',
    );
    final descriptionFocus = FocusNode();
    final quantity = TextEditingController(
      text: existing == null ? '1' : _export.quantity(existing.quantityMicros),
    );
    final unit = TextEditingController(text: existing?.unit ?? 'No');
    final rate = TextEditingController(
      text: existing == null
          ? '0'
          : (existing.rateMinor / 100).toStringAsFixed(2),
    );
    final tax = TextEditingController(
      text: existing == null
          ? '18'
          : (existing.taxBasisPoints / 100).toStringAsFixed(2),
    );
    var category = existing?.taxCategory ?? TaxCategory.material;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null ? 'Add quotation line' : 'Edit quotation line',
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RawAutocomplete<String>(
                    textEditingController: description,
                    focusNode: descriptionFocus,
                    optionsBuilder: (value) {
                      final query = value.text.trim().toLowerCase();
                      return suggestions
                          .where(
                            (item) =>
                                query.isEmpty ||
                                item.toLowerCase().contains(query),
                          )
                          .take(8);
                    },
                    onSelected: (value) => description.text = value,
                    fieldViewBuilder:
                        (
                          context,
                          controller,
                          focusNode,
                          onSubmitted,
                        ) => TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            helperText:
                                'Suggestions include saved items and common repair work.',
                            suffixIcon: Icon(Icons.auto_awesome_outlined),
                          ),
                        ),
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 500,
                            maxHeight: 260,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final learned = learnedSuggestions.contains(
                                option,
                              );
                              return ListTile(
                                leading: Icon(
                                  learned
                                      ? Icons.history
                                      : Icons.build_outlined,
                                ),
                                title: Text(option),
                                subtitle: Text(
                                  learned ? 'Previously used' : 'Common item',
                                ),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: quantity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: unit,
                          decoration: const InputDecoration(labelText: 'Unit'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: rate,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Rate (PKR)',
                            suffixIcon: PopupMenuButton<int>(
                              tooltip: 'Choose a nearby rate (PKR 10 steps)',
                              icon: const Icon(Icons.arrow_drop_down),
                              onSelected: (rupees) {
                                rate.text = rupees.toStringAsFixed(2);
                                setDialogState(() {});
                              },
                              itemBuilder: (_) {
                                final parsed = double.tryParse(
                                  rate.text.replaceAll(',', '').trim(),
                                );
                                final current = (parsed ?? 0).round();
                                return [
                                  for (final rupees in _nearbyRateRupees(
                                    current,
                                  ))
                                    PopupMenuItem<int>(
                                      value: rupees,
                                      child: Text(
                                        rupees == current
                                            ? 'PKR $rupees  (Current)'
                                            : 'PKR $rupees',
                                      ),
                                    ),
                                ];
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaxCategory>(
                    initialValue: category,
                    decoration: const InputDecoration(
                      labelText: 'Tax category',
                    ),
                    items: TaxCategory.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_categoryLabel(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => category = value);
                      tax.text = switch (value) {
                        TaxCategory.material => '18',
                        TaxCategory.labour => '16',
                        TaxCategory.exempt => '0',
                        TaxCategory.custom => tax.text,
                      };
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tax,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sales tax %'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save line'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      if (description.text.trim().isEmpty) {
        throw const FormatException('Description is required.');
      }
      final updated = QuotationLine(
        id: existing?.id ?? 'line-${DateTime.now().microsecondsSinceEpoch}',
        description: description.text.trim(),
        quantityMicros: parseQuantityMicros(quantity.text),
        unit: unit.text.trim().isEmpty ? 'No' : unit.text.trim(),
        rateMinor: parseMoneyMinor(rate.text),
        taxCategory: category,
        taxBasisPoints: parseTaxBasisPoints(tax.text),
      );
      if (updated.taxBasisPoints > 10000) {
        throw const FormatException('Tax rate must be between 0 and 100%.');
      }
      final index = existing == null
          ? -1
          : _quotation.lines.indexWhere((line) => line.id == existing.id);
      setState(() {
        if (index < 0) {
          if (insertAt != null &&
              insertAt >= 0 &&
              insertAt <= _quotation.lines.length) {
            _quotation.lines.insert(insertAt, updated);
          } else {
            _quotation.lines.add(updated);
          }
        } else {
          _quotation.lines[index] = updated;
        }
      });
      _resetCellControllers();
      _changed();
    } on FormatException catch (error) {
      if (mounted) _notice(error.message, warning: true);
    }
  }

  String _categoryLabel(TaxCategory value) => switch (value) {
    TaxCategory.material => 'Material / Purchase · 18%',
    TaxCategory.labour => 'Labour / Repair / Service · 16%',
    TaxCategory.exempt => 'Tax exempt · 0%',
    TaxCategory.custom => 'Custom rate',
  };

  Future<void> _editStamps() async {
    final left = TextEditingController(text: _quotation.leftStamp);
    final right = TextEditingController(text: _quotation.rightStamp);
    final additional = TextEditingController();
    var showBlocks = _quotation.showStampBlocks;
    var showLeft = _quotation.showLeftStamp;
    var showRight = _quotation.showRightStamp;
    final customNames = List<String>.from(_quotation.customStamps);
    final customVisible = List<bool>.generate(
      customNames.length,
      _quotation.customStampIsVisible,
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Signature blocks'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show signature blocks in final PDF'),
                    subtitle: const Text('Enabled by default'),
                    value: showBlocks,
                    onChanged: (next) =>
                        setDialogState(() => showBlocks = next),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show left signature'),
                    value: showLeft,
                    onChanged: (next) =>
                        setDialogState(() => showLeft = next ?? false),
                  ),
                  TextField(
                    controller: left,
                    decoration: const InputDecoration(
                      labelText: 'Left designation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show right signature'),
                    value: showRight,
                    onChanged: (next) =>
                        setDialogState(() => showRight = next ?? false),
                  ),
                  TextField(
                    controller: right,
                    decoration: const InputDecoration(
                      labelText: 'Right designation',
                    ),
                  ),
                  for (var index = 0; index < customNames.length; index++) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: customVisible[index],
                          onChanged: (next) => setDialogState(
                            () => customVisible[index] = next ?? false,
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            initialValue: customNames[index],
                            onChanged: (value) => customNames[index] = value,
                            decoration: InputDecoration(
                              labelText: 'Additional position ${index + 1}',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete this signature position',
                          onPressed: () => setDialogState(() {
                            customNames.removeAt(index);
                            customVisible.removeAt(index);
                          }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: additional,
                          decoration: const InputDecoration(
                            labelText: 'Add another position',
                            hintText: 'e.g. Chief Officer',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          final name = additional.text.trim();
                          if (name.isEmpty) return;
                          setDialogState(() {
                            customNames.add(name);
                            customVisible.add(true);
                            additional.clear();
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Only checked signature positions appear below totals in the final A4 PDF.',
                    style: TextStyle(color: Color(0xff5c6c66)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      _quotation.leftStamp = left.text.trim();
      _quotation.rightStamp = right.text.trim();
      _quotation.showStampBlocks = showBlocks;
      _quotation.showLeftStamp = showLeft;
      _quotation.showRightStamp = showRight;
      final savedCustomNames = customNames
          .map((name) => name.trim())
          .where((name) => name.isNotEmpty)
          .toList();
      final savedCustomVisibility = [
        for (var index = 0; index < customNames.length; index++)
          if (customNames[index].trim().isNotEmpty) customVisible[index],
      ];
      _quotation.customStamps
        ..clear()
        ..addAll(savedCustomNames);
      _quotation.customStampVisibility
        ..clear()
        ..addAll(savedCustomVisibility);
      _changed();
    }
    left.dispose();
    right.dispose();
    additional.dispose();
  }

  Future<void> _runExport(String format, {required bool share}) async {
    _quotation.title = _titleController.text;
    _quotation.fileName = _safeFileName(_fileController.text);
    if (!_quotation.isValid) {
      _notice(
        'Complete the quotation title and add at least one valid line before export.',
        warning: true,
      );
      return;
    }
    final operation = _beginOperation('Creating export file…');
    try {
      late List<int> bytes;
      late String extension;
      late String mime;
      switch (format) {
        case 'pdf':
          bytes = await _export.pdf(_quotation);
          extension = 'pdf';
          mime = 'application/pdf';
        case 'excel':
          bytes = _export.excel(_quotation);
          extension = 'xlsx';
          mime =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        default:
          bytes = _export.csv(_quotation);
          extension = 'csv';
          mime = 'text/csv';
      }
      final fileName = '${_quotation.fileName}.$extension';
      if (share) {
        await _export.share(fileName, Uint8List.fromList(bytes), mime);
      } else {
        await _export.download(fileName, Uint8List.fromList(bytes));
      }
      if (mounted && operation == _operationId) {
        _notice(
          share
              ? 'Share sheet opened. Select WhatsApp or another app.'
              : '$extension file is ready.',
        );
      }
    } on Object catch (error) {
      if (mounted && operation == _operationId) {
        _notice(
          'The file could not be created. Please try again. $error',
          warning: true,
        );
      }
    } finally {
      if (mounted && operation == _operationId) {
        setState(() => _busy = false);
      }
    }
  }

  void _notice(String message, {bool warning = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: warning
              ? const Color(0xff9a5a12)
              : const Color(0xff145c55),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 840;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xff123c38),
        foregroundColor: Colors.white,
        titleSpacing: 18,
        title: const Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              child: Image(
                image: AssetImage(
                  'assets/branding/municipal_water_quotation_icon.png',
                ),
                width: 42,
                height: 42,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Municipal Quotation Builder',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
                Text(
                  'MUNICIPAL COMMITTEE · CHISHTIAN',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.3,
                    color: Color(0xffbcd5ce),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!compact) _statusChip(),
          IconButton(
            tooltip: 'New quotation',
            onPressed: _newQuotation,
            icon: const Icon(Icons.note_add_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              if (!compact) _navigation(),
              Expanded(child: _content(compact)),
            ],
          ),
          if (_busy)
            ColoredBox(
              color: const Color(0x55000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 14),
                        Text(_busyMessage),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _cancelOperation,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel process'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: compact
          ? NavigationBar(
              selectedIndex: switch (_selectedSection) {
                4 => 1,
                5 => 2,
                _ => 0,
              },
              onDestinationSelected: (value) => setState(
                () => _selectedSection = switch (value) {
                  1 => 4,
                  2 => 5,
                  _ => 1,
                },
              ),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.edit_note),
                  label: 'Editor',
                ),
                NavigationDestination(
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  label: 'Preview',
                ),
                NavigationDestination(
                  icon: Icon(Icons.ios_share),
                  label: 'Export',
                ),
              ],
            )
          : null,
    );
  }

  Widget _statusChip() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: ActionChip(
      tooltip: 'Save draft now',
      onPressed: _save,
      avatar: Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 17),
      label: Text(_saved ? 'Draft saved' : 'Save draft'),
      backgroundColor: const Color(0xffd7ebe5),
      side: BorderSide.none,
    ),
  );

  Widget _navigation() => Container(
    width: 220,
    color: const Color(0xfff8faf7),
    padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _navItem(
          Icons.dashboard_outlined,
          'Dashboard',
          _selectedSection == 0,
          onTap: () {
            _searchController.clear();
            _refreshLibrary();
            setState(() => _selectedSection = 0);
          },
        ),
        _navItem(
          Icons.description_outlined,
          'Quotation editor',
          _selectedSection == 1,
          onTap: () => setState(() => _selectedSection = 1),
        ),
        _navItem(
          Icons.approval_outlined,
          'Stamp designer',
          false,
          onTap: _editStamps,
        ),
        _navItem(
          Icons.folder_copy_outlined,
          'Records & exports',
          _selectedSection == 2,
          onTap: () {
            _refreshLibrary();
            setState(() => _selectedSection = 2);
          },
        ),
        const Spacer(),
        const Divider(),
        _navItem(
          Icons.settings_outlined,
          'Settings',
          _selectedSection == 3,
          onTap: () => setState(() => _selectedSection = 3),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Version 1.2 · Local autosave',
            style: TextStyle(fontSize: 11, color: Color(0xff6c7772)),
          ),
        ),
      ],
    ),
  );

  Widget _navItem(
    IconData icon,
    String label,
    bool selected, {
    VoidCallback? onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: ListTile(
      selected: selected,
      selectedTileColor: const Color(0xffdcece6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(icon),
      title: Text(
        label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      onTap: onTap,
    ),
  );

  Widget _content(bool compact) {
    if (compact) {
      return switch (_selectedSection) {
        0 => _dashboardPane(),
        2 => _libraryPane(),
        3 => _settingsPane(),
        4 => _previewPane(),
        5 => _exportPane(),
        _ => _editorPane(),
      };
    }
    return switch (_selectedSection) {
      0 => _dashboardPane(),
      2 => _libraryPane(),
      3 => _settingsPane(),
      _ => _desktopEditorLayout(),
    };
  }

  Widget _desktopEditorLayout() => LayoutBuilder(
    builder: (context, constraints) {
      if (!_previewVisible) return _editorPane();
      final maximumPreview = constraints.maxWidth * .65;
      final width = _previewWidth.clamp(300.0, maximumPreview);
      return Row(
        children: [
          Expanded(child: _editorPane()),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) => setState(() {
                _previewWidth = (_previewWidth - details.delta.dx).clamp(
                  300.0,
                  maximumPreview,
                );
              }),
              child: Container(
                width: 8,
                color: const Color(0xffcbd5cf),
                child: const Icon(Icons.drag_indicator, size: 14),
              ),
            ),
          ),
          SizedBox(width: width, child: _previewPane()),
        ],
      );
    },
  );

  String _suggestFileName(String title) {
    final tanki = RegExp(
      r'city\s+water\s*works?\s+tanki\s+(?:no\.?|number)?\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(title);
    if (tanki != null) {
      return 'Quotation for City Water Works Tanki No. ${tanki.group(1)}';
    }
    final cleaned = title.trim();
    return cleaned.isEmpty ? 'Municipal Quotation' : 'Quotation for $cleaned';
  }

  Widget _editorPane() => Column(
    children: [
      _topActions(),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quotation workspace',
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff173d39),
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Review every field before final export.',
                        style: TextStyle(color: Color(0xff65736e)),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addOrEditLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sourceCard(),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      number: '01',
                      title: 'Document details',
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleController,
                      onChanged: (_) => _changed(),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Quotation title *',
                        helperText:
                            'Only the work title appears in the final document.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _fileController,
                      onChanged: (_) => _changed(),
                      decoration: const InputDecoration(
                        labelText: 'Download file name',
                        prefixIcon: Icon(Icons.drive_file_rename_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xfff8faf7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xffd7dfda)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(
                          _quotation.documentDate == null
                              ? 'Document date not detected'
                              : DateFormat(
                                  'dd/MM/yyyy',
                                ).format(_quotation.documentDate!),
                        ),
                        subtitle: Text(
                          'App record only · Created ${DateFormat('dd/MM/yyyy, hh:mm a').format(_quotation.createdAt)} · Updated ${DateFormat('dd/MM/yyyy, hh:mm a').format(_quotation.updatedAt)}\nThis date is never printed in the PDF.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Change document date',
                          onPressed: _pickDocumentDate,
                          icon: const Icon(Icons.edit_calendar_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionTitle(
                            number: '02',
                            title: 'Items & tax',
                          ),
                        ),
                        Text(
                          '${_quotation.lines.length} lines',
                          style: const TextStyle(color: Color(0xff65736e)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (_quotation.lines.isEmpty)
                      _emptyLines()
                    else
                      _itemsEditor(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _summaryCard(),
            const SizedBox(height: 16),
            _stampCard(),
            const SizedBox(height: 84),
          ],
        ),
      ),
      _bottomActions(),
    ],
  );

  Widget _sourceCard() => Card(
    color: const Color(0xfffffbef),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xffffe3a8),
            child: Icon(
              Icons.document_scanner_outlined,
              color: Color(0xff7b5316),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Source document',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  _sourceMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xff6d6a5f),
                  ),
                ),
                if (_sourceQuotations.length > 1) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _sourceQuotationIndex > 0
                            ? () => _showSourceQuotation(
                                _sourceQuotationIndex - 1,
                              )
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 18),
                        label: const Text('Previous'),
                      ),
                      Text(
                        'Quotation ${_sourceQuotationIndex + 1} of ${_sourceQuotations.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      FilledButton.icon(
                        onPressed:
                            _sourceQuotationIndex < _sourceQuotations.length - 1
                            ? () => _showSourceQuotation(
                                _sourceQuotationIndex + 1,
                              )
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text('Next quotation'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pickSource,
            icon: const Icon(Icons.upload_file),
            label: const Text('PDF / image'),
          ),
        ],
      ),
    ),
  );

  Widget _emptyLines() => Container(
    padding: const EdgeInsets.symmetric(vertical: 32),
    alignment: Alignment.center,
    child: Column(
      children: [
        const Icon(Icons.playlist_add, size: 42, color: Color(0xff7e9089)),
        const SizedBox(height: 8),
        const Text(
          'No quotation lines yet',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _addOrEditLine,
          icon: const Icon(Icons.add),
          label: const Text('Add first item'),
        ),
      ],
    ),
  );

  void _resetCellControllers() {
    for (final controller in _cellControllers.values) {
      controller.dispose();
    }
    _cellControllers.clear();
  }

  TextEditingController _cellController(
    QuotationLine line,
    String field,
    String initialValue,
  ) => _cellControllers.putIfAbsent(
    '${line.id}:$field',
    () => TextEditingController(text: initialValue),
  );

  String _moneyInput(int minor) => (minor / 100).toStringAsFixed(2);

  List<int> _nearbyRateRupees(int currentRupees) => <int>{
    for (var offset = -40; offset <= 40; offset += 10)
      if (currentRupees + offset >= 0) currentRupees + offset,
  }.toList()..sort();

  void _setCellText(QuotationLine line, String field, String value) {
    final controller = _cellControllers['${line.id}:$field'];
    if (controller == null || controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _updateInlineCell(QuotationLine line, String field, String value) {
    try {
      switch (field) {
        case 'description':
          line.description = value;
        case 'quantity':
          line.quantityMicros = parseQuantityMicros(value);
          _setCellText(line, 'amount', _moneyInput(line.amountMinor));
        case 'unit':
          line.unit = value;
        case 'rate':
          line.rateMinor = parseMoneyMinor(value);
          _setCellText(line, 'amount', _moneyInput(line.amountMinor));
        case 'amount':
          final amountMinor = parseMoneyMinor(value);
          if (line.quantityMicros <= 0) return;
          line.rateMinor =
              ((amountMinor * 1000000) + (line.quantityMicros ~/ 2)) ~/
              line.quantityMicros;
          _setCellText(line, 'rate', _moneyInput(line.rateMinor));
        case 'tax':
          final basisPoints = parseTaxBasisPoints(value);
          if (basisPoints > 10000) return;
          line.taxBasisPoints = basisPoints;
          line.taxCategory = TaxCategory.custom;
      }
      _changed();
    } on FormatException {
      // Partial numeric input remains editable until it becomes valid.
    }
  }

  Widget _itemsEditor() => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 700) {
        return Column(
          children: _quotation.lines
              .asMap()
              .entries
              .map((entry) => _lineCard(entry.key, entry.value))
              .toList(),
        );
      }
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffcfdad3)),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 980,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xffdfe6df)),
                verticalInside: BorderSide(color: Color(0xffe7ece8)),
              ),
              columnWidths: const {
                0: FixedColumnWidth(45),
                1: FixedColumnWidth(205),
                2: FixedColumnWidth(70),
                3: FixedColumnWidth(65),
                4: FixedColumnWidth(115),
                5: FixedColumnWidth(115),
                6: FixedColumnWidth(70),
                7: FixedColumnWidth(100),
                8: FixedColumnWidth(110),
                9: FixedColumnWidth(85),
              },
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: Color(0xff145c55)),
                  children: [
                    for (final entry in const [
                      'Sr.',
                      'Description',
                      'Qty',
                      'Unit',
                      'Rate',
                      'Amount',
                      'Tax %',
                      'S. Tax',
                      'Total',
                      'Delete',
                    ].asMap().entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 11,
                        ),
                        child: Text(
                          entry.value,
                          textAlign: entry.key == 1
                              ? TextAlign.left
                              : TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                for (var index = 0; index < _quotation.lines.length; index++)
                  _editableTableRow(index, _quotation.lines[index]),
              ],
            ),
          ),
        ),
      );
    },
  );

  TableRow _editableTableRow(int index, QuotationLine line) => TableRow(
    decoration: BoxDecoration(
      color: index.isEven ? Colors.white : const Color(0xfff8faf7),
    ),
    children: [
      _plainTableCell('${index + 1}', center: true),
      _editableTableCell(
        line,
        'description',
        line.description,
        keyboardType: TextInputType.text,
      ),
      _editableTableCell(
        line,
        'quantity',
        _export.quantity(line.quantityMicros),
      ),
      _editableTableCell(
        line,
        'unit',
        line.unit,
        keyboardType: TextInputType.text,
      ),
      _rateTableCell(line),
      _editableTableCell(line, 'amount', _moneyInput(line.amountMinor)),
      _editableTableCell(
        line,
        'tax',
        (line.taxBasisPoints / 100).toStringAsFixed(2),
      ),
      _plainTableCell(_export.money(line.salesTaxMinor), numeric: true),
      _plainTableCell(
        _export.money(line.totalMinor),
        numeric: true,
        bold: true,
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Insert a new item below this row',
              visualDensity: VisualDensity.compact,
              onPressed: () => _addOrEditLine(null, index + 1),
              icon: const Icon(Icons.add_circle_outline, size: 19),
            ),
            IconButton(
              tooltip: 'Delete this reference item',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => _quotation.lines.removeAt(index));
                _resetCellControllers();
                _changed();
              },
              icon: const Icon(Icons.delete_outline, size: 19),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _editableTableCell(
    QuotationLine line,
    String field,
    String initialValue, {
    TextInputType keyboardType = const TextInputType.numberWithOptions(
      decimal: true,
    ),
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
    child: TextField(
      controller: _cellController(line, field, initialValue),
      keyboardType: keyboardType,
      onChanged: (value) => _updateInlineCell(line, field, value),
      maxLines: field == 'description' ? 2 : 1,
      textAlign: field == 'description' ? TextAlign.left : TextAlign.center,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: const Color(0xfffbfcfa),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
      ),
    ),
  );

  Widget _rateTableCell(QuotationLine line) {
    final currentRupees = (line.rateMinor / 100).round();
    final nearbyRates = _nearbyRateRupees(currentRupees);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: TextField(
        controller: _cellController(line, 'rate', _moneyInput(line.rateMinor)),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (value) => _updateInlineCell(line, 'rate', value),
        maxLines: 1,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: const Color(0xfffbfcfa),
          contentPadding: const EdgeInsets.only(left: 8, top: 9, bottom: 9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7)),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 32,
            minHeight: 32,
          ),
          suffixIcon: PopupMenuButton<int>(
            tooltip: 'Choose a nearby rate (PKR 10 steps)',
            icon: const Icon(Icons.arrow_drop_down, size: 20),
            onSelected: (rupees) {
              final value = rupees.toStringAsFixed(2);
              _setCellText(line, 'rate', value);
              _updateInlineCell(line, 'rate', value);
            },
            itemBuilder: (context) => [
              for (final rupees in nearbyRates)
                PopupMenuItem<int>(
                  value: rupees,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('PKR $rupees'),
                      if (rupees == currentRupees)
                        const Padding(
                          padding: EdgeInsets.only(left: 14),
                          child: Text(
                            'Current',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plainTableCell(
    String value, {
    bool center = false,
    bool numeric = false,
    bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 13),
    child: Text(
      value,
      textAlign: center
          ? TextAlign.center
          : numeric
          ? TextAlign.center
          : TextAlign.left,
      style: TextStyle(
        fontSize: 12,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
  );

  Widget _lineCard(int index, QuotationLine line) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xffdfe6df)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xffe4eee9),
          child: Text(
            '${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.description,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  Text(
                    '${_export.quantity(line.quantityMicros)} ${line.unit} × PKR ${_export.money(line.rateMinor)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff61706b),
                    ),
                  ),
                  Text(
                    '${line.taxBasisPoints / 100}% tax',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff14685f),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'PKR ${_export.money(line.totalMinor)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            Text(
              'Tax ${_export.money(line.salesTaxMinor)}',
              style: const TextStyle(fontSize: 11, color: Color(0xff6d7773)),
            ),
          ],
        ),
        PopupMenuButton<String>(
          tooltip: 'Line actions',
          onSelected: (value) {
            if (value == 'edit') _addOrEditLine(line);
            if (value == 'duplicate') {
              _quotation.lines.insert(
                index + 1,
                line.copy(id: 'line-${DateTime.now().microsecondsSinceEpoch}'),
              );
              _changed();
            }
            if (value == 'up' && index > 0) {
              setState(() {
                final item = _quotation.lines.removeAt(index);
                _quotation.lines.insert(index - 1, item);
              });
              _changed();
            }
            if (value == 'delete') {
              setState(() => _quotation.lines.removeAt(index));
              _changed();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
            if (index > 0)
              const PopupMenuItem(value: 'up', child: Text('Move up')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    ),
  );

  Widget _summaryCard() => Card(
    color: const Color(0xff123c38),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _summaryRow('Subtotal', _quotation.subtotalMinor),
          const SizedBox(height: 8),
          _summaryRow('Sales tax', _quotation.taxMinor),
          const Divider(color: Color(0xff51716c), height: 24),
          _summaryRow('Grand total', _quotation.grandTotalMinor, large: true),
        ],
      ),
    ),
  );

  Widget _summaryRow(String label, int value, {bool large = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          color: large ? Colors.white : const Color(0xffc4d5d1),
          fontWeight: large ? FontWeight.w800 : FontWeight.w500,
          fontSize: large ? 17 : 14,
        ),
      ),
      Text(
        'PKR ${_export.money(value)}',
        style: TextStyle(
          color: large ? const Color(0xffffd071) : Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: large ? 20 : 15,
        ),
      ),
    ],
  );

  Widget _stampCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionTitle(number: '03', title: 'Approvals'),
              ),
              TextButton.icon(
                onPressed: _editStamps,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit labels'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!_quotation.showStampBlocks)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Signature blocks are hidden'),
              subtitle: Text('They will not appear in the preview or exports.'),
            )
          else if (_visibleStampLabels().isEmpty)
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('All individual positions are hidden'),
              subtitle: Text('Use Edit labels to show one or more positions.'),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _visibleStampLabels()
                  .map(
                    (label) =>
                        SizedBox(width: 220, child: _stampPreview(label)),
                  )
                  .toList(),
            ),
        ],
      ),
    ),
  );

  List<String> _visibleStampLabels() => [
    if (_quotation.showLeftStamp && _quotation.leftStamp.trim().isNotEmpty)
      _quotation.leftStamp,
    if (_quotation.showRightStamp && _quotation.rightStamp.trim().isNotEmpty)
      _quotation.rightStamp,
    for (var i = 0; i < _quotation.customStamps.length; i++)
      if (_quotation.customStampIsVisible(i) &&
          _quotation.customStamps[i].trim().isNotEmpty)
        _quotation.customStamps[i],
  ];

  Widget _stampPreview(String label) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xfff8faf7),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xffd7dfda)),
    ),
    child: Column(
      children: [
        const SizedBox(height: 25),
        const Divider(color: Color(0xff567069)),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const Text(
          'MC Chishtian',
          style: TextStyle(
            fontSize: 11,
            color: Color(0xff173d39),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _topActions() => Material(
    color: Colors.white,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Row(
        children: [
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _saveAsRecord,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save record'),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: _previewVisible ? 'Hide A4 preview' : 'Show A4 preview',
            onPressed: () {
              setState(() => _previewVisible = !_previewVisible);
              _database.setSetting(
                'preview_visible',
                _previewVisible.toString(),
              );
            },
            icon: Icon(
              _previewVisible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Print PDF',
            onPressed: _quotation.isValid
                ? () => _export.printPdf(_quotation)
                : null,
            icon: const Icon(Icons.print_outlined),
          ),
          FilledButton.icon(
            onPressed: () => _runExport('pdf', share: false),
            icon: const Icon(Icons.download),
            label: const Text('Download PDF'),
          ),
        ],
      ),
    ),
  );

  Widget _bottomActions() => Material(
    color: Colors.white,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TextButton.icon(
                onPressed: _editStamps,
                icon: const Icon(Icons.approval_outlined),
                label: const Text('Signature blocks'),
              ),
              const SizedBox(width: 24),
              OutlinedButton.icon(
                onPressed: () => _runExport('excel', share: false),
                icon: const Icon(Icons.table_view_outlined),
                label: const Text('Excel'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _runExport('csv', share: false),
                icon: const Icon(Icons.grid_on_outlined),
                label: const Text('CSV'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _runExport('pdf', share: true),
                icon: const Icon(Icons.ios_share),
                label: const Text('Share / WhatsApp'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _previewPane() => Container(
    color: const Color(0xffdfe5df),
    child: Column(
      children: [
        Container(
          color: const Color(0xffedf1ed),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 19),
              const SizedBox(width: 8),
              const Text(
                'LIVE A4 PREVIEW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .8,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(_quotation.isValid ? 'Ready' : 'Needs review'),
                avatar: Icon(
                  _quotation.isValid
                      ? Icons.verified_outlined
                      : Icons.warning_amber,
                  size: 16,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                tooltip: 'Hide preview',
                onPressed: () {
                  setState(() => _previewVisible = false);
                  _database.setSetting('preview_visible', 'false');
                },
                icon: const Icon(Icons.close_fullscreen, size: 18),
              ),
            ],
          ),
        ),
        Expanded(
          child: PdfPreview(
            key: ValueKey(_quotation.encode()),
            build: (_) => _export.pdf(_quotation),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowPrinting: true,
            allowSharing: true,
            initialPageFormat: PdfPageFormat.a4,
            pdfFileName: '${_quotation.fileName}.pdf',
            loadingWidget: const Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
    ),
  );

  Widget _dashboardPane() {
    final references = _libraryRecords.where((record) => record.isReference);
    final edited = _libraryRecords.where(
      (record) =>
          !record.isReference &&
          record.quotation.recordType == QuotationRecordType.edited,
    );
    final drafts = _libraryRecords.where(
      (record) =>
          !record.isReference &&
          record.quotation.recordType == QuotationRecordType.draft,
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xff173d39),
                    ),
                  ),
                  Text('Your locally saved quotation workspace.'),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _newQuotation,
              icon: const Icon(Icons.add),
              label: const Text('New quotation'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickSource,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import PDF / image'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard('Imported references', references.length, Icons.folder),
            _metricCard('Edited quotations', edited.length, Icons.edit_note),
            _metricCard('Autosaved drafts', drafts.length, Icons.history),
            _metricCard('All records', _libraryRecords.length, Icons.storage),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent records',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _selectedSection = 2),
              icon: const Icon(Icons.search),
              label: const Text('Search all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_libraryRecords.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No saved records yet. Import or create a quotation.',
              ),
            ),
          )
        else
          for (final record in _libraryRecords.take(8)) _recordTile(record),
      ],
    );
  }

  Widget _metricCard(String label, int count, IconData icon) => SizedBox(
    width: 210,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xffead7aa),
              foregroundColor: Color(0xff123c38),
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _libraryPane() {
    final visible = _libraryRecords.where((record) {
      return switch (_libraryFilter) {
        'references' => record.isReference,
        'edited' =>
          !record.isReference &&
              record.quotation.recordType == QuotationRecordType.edited,
        'drafts' =>
          !record.isReference &&
              record.quotation.recordType == QuotationRecordType.draft,
        _ => true,
      };
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Records, search & exports',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xff173d39),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Imported references remain separate from edited quotations and drafts.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (_) => _refreshLibrary(),
          decoration: InputDecoration(
            labelText: 'Search motor, transformer, pump, item, or filename',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _refreshLibrary();
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in const {
              'all': 'All',
              'references': 'Imported references',
              'edited': 'Edited quotations',
              'drafts': 'Drafts',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: _libraryFilter == entry.key,
                onSelected: (_) => setState(() => _libraryFilter = entry.key),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No matching records found.'),
            ),
          )
        else
          for (final record in visible) _recordTile(record),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Current quotation exports',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        _exportTile(
          Icons.picture_as_pdf,
          'PDF',
          'Printer-friendly A4 quotation',
          () => _runExport('pdf', share: false),
        ),
        _exportTile(
          Icons.table_view,
          'Excel',
          'Editable workbook',
          () => _runExport('excel', share: false),
        ),
        _exportTile(
          Icons.grid_on,
          'CSV',
          'Universal table file',
          () => _runExport('csv', share: false),
        ),
      ],
    );
  }

  Widget _recordTile(StoredQuotation record) {
    final quotation = record.quotation;
    final category = record.isReference
        ? 'Imported reference'
        : quotation.recordType == QuotationRecordType.edited
        ? 'Edited quotation'
        : 'Draft';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: const Color(0xffead7aa),
          foregroundColor: const Color(0xff123c38),
          child: Icon(
            record.isReference
                ? Icons.picture_as_pdf_outlined
                : Icons.edit_note,
          ),
        ),
        title: Text(
          quotation.title.isEmpty ? 'Untitled quotation' : quotation.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$category · ${quotation.lines.length} items · ${DateFormat('dd/MM/yyyy, hh:mm a').format(quotation.updatedAt)}${quotation.sourceName.isEmpty ? '' : '\n${quotation.sourceName}'}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'open') _openRecord(record);
            if (value == 'delete') _deleteStoredRecord(record);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('Open and edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete record')),
          ],
        ),
        onTap: () => _openRecord(record),
      ),
    );
  }

  Future<void> _openRecord(StoredQuotation record) async {
    _autosave?.cancel();
    _repairImportedDescriptions(record.quotation);
    if (record.isReference) {
      _quotation = record.quotation.copy(
        id: 'quotation-${DateTime.now().microsecondsSinceEpoch}',
        recordType: QuotationRecordType.draft,
      );
      await _database.save(_quotation);
      _sourceMessage =
          '${record.quotation.sourceName} · Opened from imported references';
    } else {
      _quotation = record.quotation;
      _sourceMessage = _quotation.sourceName.isEmpty
          ? 'Saved local quotation'
          : '${_quotation.sourceName} · Saved working record';
    }
    _sourceQuotations = [];
    _sourceQuotationIndex = 0;
    _resetCellControllers();
    _syncControllers();
    setState(() {
      _selectedSection = 1;
      _saved = true;
    });
  }

  Future<void> _deleteStoredRecord(StoredQuotation record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved record?'),
        content: Text(
          'Delete "${record.quotation.title}" from local storage? This does not delete the original PDF file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _database.deleteRecord(record);
    await _refreshLibrary();
  }

  Widget _settingsPane() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Settings',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Color(0xff173d39),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Local storage, preview, drafts, and complete backup.'),
      const SizedBox(height: 18),
      Card(
        child: Column(
          children: [
            SwitchListTile(
              title: const Text('Show live A4 preview'),
              subtitle: const Text(
                'The preview can also be resized or hidden from its header.',
              ),
              value: _previewVisible,
              onChanged: (value) {
                setState(() => _previewVisible = value);
                _database.setSetting('preview_visible', value.toString());
              },
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.save_outlined),
              title: Text('Automatic draft saving'),
              subtitle: Text(
                'Every valid edit is saved locally after 650 milliseconds.',
              ),
              trailing: Icon(Icons.verified_outlined),
            ),
            const Divider(height: 1),
            FutureBuilder<String>(
              future: _database.location(),
              builder: (context, snapshot) => ListTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('SQLite database location'),
                subtitle: Text(snapshot.data ?? 'Loading…'),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete app backup',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Includes imported references, edited quotations, drafts, learned item suggestions, dates, signatures, and settings.',
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Export complete backup'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _restoreBackup,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore backup'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> _exportBackup() async {
    final operation = _beginOperation('Creating complete app backup…');
    try {
      final bytes = await _database.exportBackup();
      if (operation != _operationId) return;
      final timestamp = DateFormat('dd-MM-yyyy_HHmm').format(DateTime.now());
      await _export.download(
        'Municipal_Quotation_Backup_$timestamp.json',
        bytes,
      );
      if (mounted && operation == _operationId) {
        _notice('Complete backup exported successfully.');
      }
    } finally {
      if (mounted && operation == _operationId) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _restoreBackup() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final bytes = selected?.files.single.bytes;
    if (bytes == null) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore complete backup?'),
        content: const Text(
          'Current local records will be replaced by the selected backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final operation = _beginOperation('Restoring complete app backup…');
    try {
      await _database.restoreBackup(bytes);
      if (operation != _operationId) return;
      await _restore();
      if (mounted) _notice('Backup restored successfully.');
    } finally {
      if (mounted && operation == _operationId) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _exportPane() => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const Text(
        'Download & share',
        style: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: Color(0xff173d39),
        ),
      ),
      const SizedBox(height: 6),
      const Text('Choose a complete document or spreadsheet format.'),
      const SizedBox(height: 18),
      _exportTile(
        Icons.picture_as_pdf,
        'PDF',
        'Exact A4 quotation with totals and signatures',
        () => _runExport('pdf', share: false),
      ),
      _exportTile(
        Icons.table_view,
        'Excel',
        'Editable .xlsx workbook with calculated totals',
        () => _runExport('excel', share: false),
      ),
      _exportTile(
        Icons.grid_on,
        'CSV',
        'Universal tabular data file',
        () => _runExport('csv', share: false),
      ),
      _exportTile(
        Icons.share,
        'Share / WhatsApp',
        'Open the device share sheet with the PDF attached',
        () => _runExport('pdf', share: true),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => setState(() => _selectedSection = 4),
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('Review A4 preview'),
      ),
    ],
  );

  Widget _exportTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.all(14),
      leading: CircleAvatar(
        backgroundColor: const Color(0xffead7aa),
        foregroundColor: const Color(0xff123c38),
        child: Icon(icon),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.number, required this.title});
  final String number;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xffd9ebe5),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          number,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xff145c55),
          ),
        ),
      ),
      const SizedBox(width: 9),
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Color(0xff23433f),
        ),
      ),
    ],
  );
}
