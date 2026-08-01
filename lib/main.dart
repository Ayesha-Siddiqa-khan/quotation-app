import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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
  final Map<String, TextEditingController> _cellControllers = {};
  Timer? _autosave;
  var _busy = false;
  var _saved = true;
  var _sourceMessage = 'No source attached · Manual quotation';
  var _selectedSection = 0;
  var _sourceQuotationIndex = 0;
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
      if (saved != null) _quotation = saved;
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
    _autosave?.cancel();
    setState(() => _saved = false);
    _autosave = Timer(const Duration(milliseconds: 650), _save);
  }

  Future<void> _save() async {
    await _database.save(_quotation);
    if (mounted) setState(() => _saved = true);
  }

  String _safeFileName(String value) {
    final safe = value.trim().replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');
    return safe.isEmpty ? 'municipal_quotation' : safe;
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
    setState(() => _busy = true);
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
      if (importedPages.isEmpty) {
        throw const FormatException('No quotation pages were found.');
      }
      _autosave?.cancel();
      _sourceQuotations = [
        for (final imported in importedPages)
          Quotation(
            title: imported.title.trim(),
            fileName: _suggestFileName(imported.title),
            lines: imported.lines,
            leftStamp: _quotation.leftStamp,
            rightStamp: _quotation.rightStamp,
            showStampBlocks: _quotation.showStampBlocks,
            customStamps: List<String>.from(_quotation.customStamps),
          ),
      ];
      _sourceQuotationIndex = 0;
      _quotation = _sourceQuotations.first;
      _resetCellControllers();
      _sourceMessage =
          '${file.name} · ${_sourceLabel(importedPages.first.kind)}';
      _syncControllers();
      _changed();
      if (mounted) {
        _notice(
          importedPages.length == 1
              ? importedPages.first.warning
              : '${importedPages.length} separate quotations detected. Review quotation 1, then use Next quotation.',
          warning: true,
        );
      }
    } on Object catch (error) {
      if (mounted) {
        _notice(
          'Could not read this source. Try an unlocked PDF or a clear JPG/PNG. $error',
          warning: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _sourceLabel(SourceKind kind) => switch (kind) {
    SourceKind.digitalPdf => 'Digital-text PDF',
    SourceKind.scannedPdf => 'Scanned PDF · review required',
    SourceKind.mixedPdf => 'Mixed PDF · review required',
    SourceKind.image => 'Image OCR',
  };

  Future<void> _newQuotation() async {
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
    _changed();
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

  Future<void> _addOrEditLine([QuotationLine? existing]) async {
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
          _quotation.lines.add(updated);
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
    final showBlocks = ValueNotifier<bool>(_quotation.showStampBlocks);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signature blocks'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: showBlocks,
                builder: (context, value, _) => SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show signature blocks in final PDF'),
                  subtitle: const Text('Enabled by default'),
                  value: value,
                  onChanged: (next) => showBlocks.value = next,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: left,
                decoration: const InputDecoration(
                  labelText: 'Left designation',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: right,
                decoration: const InputDecoration(
                  labelText: 'Right designation',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: additional,
                decoration: const InputDecoration(
                  labelText: 'Add another position (optional)',
                  hintText: 'e.g. Chief Officer',
                ),
              ),
              if (_quotation.customStamps.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Current additional positions: ${_quotation.customStamps.join(', ')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'Both blocks stay together below totals on the final A4 page.',
                style: TextStyle(color: Color(0xff5c6c66)),
              ),
            ],
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
    );
    if (accepted == true) {
      _quotation.leftStamp = left.text.trim();
      _quotation.rightStamp = right.text.trim();
      _quotation.showStampBlocks = showBlocks.value;
      if (additional.text.trim().isNotEmpty) {
        _quotation.customStamps.add(additional.text.trim());
      }
      _changed();
    }
    showBlocks.dispose();
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
    setState(() => _busy = true);
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
      if (mounted) {
        _notice(
          share
              ? 'Share sheet opened. Select WhatsApp or another app.'
              : '$extension file is ready.',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        _notice(
          'The file could not be created. Please try again. $error',
          warning: true,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
            CircleAvatar(
              backgroundColor: Color(0xffd5aa55),
              foregroundColor: Color(0xff123c38),
              child: Icon(Icons.account_balance_rounded),
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
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Preparing your document…'),
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
              selectedIndex: _selectedSection,
              onDestinationSelected: (value) =>
                  setState(() => _selectedSection = value),
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
    child: Chip(
      avatar: Icon(_saved ? Icons.cloud_done_outlined : Icons.sync, size: 17),
      label: Text(_saved ? 'Draft saved' : 'Saving…'),
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
        _navItem(Icons.dashboard_outlined, 'Dashboard', false),
        _navItem(Icons.description_outlined, 'Quotation editor', true),
        _navItem(
          Icons.approval_outlined,
          'Stamp designer',
          false,
          onTap: _editStamps,
        ),
        _navItem(Icons.file_download_outlined, 'Exports', false),
        const Spacer(),
        const Divider(),
        _navItem(Icons.settings_outlined, 'Settings', false),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Version 1.0 · Local autosave',
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
        0 => _editorPane(),
        1 => _previewPane(),
        _ => _exportPane(),
      };
    }
    return Row(
      children: [
        Expanded(flex: 7, child: _editorPane()),
        const VerticalDivider(width: 1),
        Expanded(flex: 5, child: _previewPane()),
      ],
    );
  }

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
            width: 1120,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              border: const TableBorder(
                horizontalInside: BorderSide(color: Color(0xffdfe6df)),
                verticalInside: BorderSide(color: Color(0xffe7ece8)),
              ),
              columnWidths: const {
                0: FixedColumnWidth(48),
                1: FixedColumnWidth(270),
                2: FixedColumnWidth(82),
                3: FixedColumnWidth(75),
                4: FixedColumnWidth(120),
                5: FixedColumnWidth(120),
                6: FixedColumnWidth(78),
                7: FixedColumnWidth(112),
                8: FixedColumnWidth(120),
                9: FixedColumnWidth(70),
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
                      'Action',
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
              tooltip: 'Edit in dialog',
              visualDensity: VisualDensity.compact,
              onPressed: () => _addOrEditLine(line),
              icon: const Icon(Icons.open_in_new, size: 18),
            ),
            IconButton(
              tooltip: 'Delete line',
              visualDensity: VisualDensity.compact,
              onPressed: () {
                setState(() => _quotation.lines.removeAt(index));
                _resetCellControllers();
                _changed();
              },
              icon: const Icon(Icons.delete_outline, size: 18),
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
          else
            Row(
              children: [
                Expanded(child: _stampPreview(_quotation.leftStamp)),
                const SizedBox(width: 12),
                Expanded(child: _stampPreview(_quotation.rightStamp)),
              ],
            ),
          if (_quotation.showStampBlocks &&
              _quotation.customStamps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _quotation.customStamps
                  .map(
                    (label) =>
                        SizedBox(width: 220, child: _stampPreview(label)),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ),
  );

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
          OutlinedButton.icon(
            onPressed: _pickSource,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import PDF / image'),
          ),
          const Spacer(),
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
        onPressed: () => setState(() => _selectedSection = 1),
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
      leading: CircleAvatar(child: Icon(icon)),
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
