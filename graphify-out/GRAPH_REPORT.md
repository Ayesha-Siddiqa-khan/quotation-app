# Graph Report - .  (2026-08-01)

## Corpus Check
- Large corpus: 149 files · ~556,623 words. Semantic extraction will be expensive (many Claude tokens). Consider running on a subfolder.

## Summary
- 993 nodes · 1201 edges · 61 communities (51 shown, 10 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 36 edges (avg confidence: 0.83)
- Token cost: 2,800 input · 2,200 output

## Community Hubs (Navigation)
- Darwin OCR Bindings
- Core App Screens
- Windows C Types
- Windows Flutter Shell
- Quotation Model
- macOS App Shell
- Export Service
- Import Service
- PRD Spec & Design
- OCR Platform Interface
- FFI Type Aliases
- Linux Flutter Shell
- FFI Struct Types
- Docs & Packaging
- Local Database
- Windows Type Defs
- App Tests
- Web Manifest
- InnoSetup C# Example
- FFIgen Tooling
- OCR Package API
- Windows Int Types
- Darwin FS Types
- Darwin ID Types
- Pointer Types
- Native Build Hooks
- Windows Clock Types
- OCR Example App
- User Address Types
- Opaque FFI Types
- Quotation Workspace State
- 64-bit Int Types
- InnoSetup C Example
- Android MainActivity
- 16-bit Int Types
- 32-bit Int Types
- 8-bit Int Types
- App Widgets
- Inode Types
- Unsigned Short
- Unsigned Long Long
- Unsigned Char
- Fast 16-bit Types
- Fast 32-bit Types
- Fast 64-bit Types
- InnoSetup Delphi Example
- ObjC Runtime Types
- Short Int
- Signed Char
- Vision Request Types
- Mode Types
- iOS Launch Readme
- C# Project Example
- Web Index

## God Nodes (most connected - your core abstractions)
1. `_` - 266 edges
2. `Win32Window` - 22 edges
3. `Municipal Quotation Builder` - 16 edges
4. `municipal_quotation_builder package` - 13 edges
5. `MessageHandler` - 12 edges
6. `FlutterWindow` - 10 edges
7. `Create` - 10 edges
8. `WndProc` - 10 edges
9. `MessageHandler` - 9 edges
10. `platform_ocr package` - 9 edges

## Surprising Connections (you probably didn't know these)
- `Quotation Alignment Preview (PDF)` --conceptually_related_to--> `Municipal Quotation Builder`  [AMBIGUOUS]
  tmp/pdfs/quotation-alignment-preview.pdf → README.md
- `A4 Output Specification` --conceptually_related_to--> `quotation-verification.pdf (output artifact)`  [INFERRED]
  Municipal_Quotation_Builder_PRD.md → output/pdf/quotation-verification.pdf
- `A4 Output Specification` --conceptually_related_to--> `quotation-monochrome-preview.pdf (output artifact)`  [INFERRED]
  Municipal_Quotation_Builder_PRD.md → tmp/pdfs/quotation-monochrome-preview.pdf
- `Municipal Quotation Builder` --semantically_similar_to--> `municipal_quotation_builder package`  [INFERRED] [semantically similar]
  Municipal_Quotation_Builder_PRD.md → pubspec.yaml
- `OCR & Document Detection Path` --semantically_similar_to--> `google_mlkit_text_recognition`  [INFERRED] [semantically similar]
  Municipal_Quotation_Builder_PRD.md → pubspec.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **PDF Extraction Pipeline** — municipal_quotation_builder_prd_supplier_invoice_pdf, municipal_quotation_builder_prd_ocr_path, municipal_quotation_builder_prd_title_extraction_rule, municipal_quotation_builder_prd_line_extraction_rule, municipal_quotation_builder_prd_extraction_json_contract [EXTRACTED 1.00]
- **A4 Quotation Generation Flow** — municipal_quotation_builder_prd_a4_output_spec, municipal_quotation_builder_prd_stamp_blocks, pubspec_pdf_package, pubspec_printing_package, output_pdf_quotation_verification [EXTRACTED 1.00]
- **Quotation Data Model** — municipal_quotation_builder_prd_quotation_data_model, municipal_quotation_builder_prd_quotationline, municipal_quotation_builder_prd_stampblock_model, municipal_quotation_builder_prd_tax_rules [EXTRACTED 1.00]
- **platform_ocr Cross-Platform Native OCR Architecture** — third_party_platform_ocr_readme_platform_ocr, third_party_platform_ocr_readme_windows_media_ocr, third_party_platform_ocr_readme_vision_framework, third_party_platform_ocr_readme_ocr_cabi, third_party_platform_ocr_pubspec_image [EXTRACTED 0.95]
- **Municipal Quotation Builder Windows Distribution** — readme_municipal_quotation_builder, installer_portable_readme_self_contained_windows_package, installer_portable_readme_setup_exe [INFERRED 0.85]

## Communities (61 total, 10 thin omitted)

### Community 0 - "Darwin OCR Bindings"
Cohesion: 0.01
Nodes (248): >, CGPoint, CGRect, external CMTime, ObjCObjectImpl>, _, alloc, allocWithZone (+240 more)

### Community 1 - "Core App Screens"
Cohesion: 0.03
Nodes (74): dart:async, export_service.dart, import_service.dart, _addOrEditLine, _autosave, _bottomActions, build, _busy (+66 more)

### Community 2 - "Windows C Types"
Cohesion: 0.03
Nodes (63): Array, external, external int, __arg, __builtin_va_list, __cleanup_stack, Dart__darwin_clock_t, Dart__darwin_ct_rune_t (+55 more)

### Community 3 - "Windows Flutter Shell"
Cohesion: 0.06
Nodes (53): PluginRegistry, Point, Size, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM (+45 more)

### Community 4 - "Quotation Model"
Cohesion: 0.04
Nodes (44): bool get, int get, amountMinor, cleaned, copy, customStamps, decode, description (+36 more)

### Community 5 - "macOS App Shell"
Cohesion: 0.05
Nodes (30): Any, Cocoa, file_picker, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterMacOS (+22 more)

### Community 6 - "Export Service"
Cohesion: 0.05
Nodes (41): bindings.g.dart, dart:convert, dart:ffi, dart:typed_data, csv, download, excel, ExportService (+33 more)

### Community 7 - "Import Service"
Cohesion: 0.05
Nodes (41): _capitalise, _category, centerX, centerY, _combine, copyWith, _formatTitle, fromImage (+33 more)

### Community 8 - "PRD Spec & Design"
Cohesion: 0.07
Nodes (39): analysis_options.yaml (flutter_lints), A4 Output Specification, Confidence Scoring, Decimal Arithmetic Requirement, Document Processing Service, Extraction JSON Contract, Flutter Client Architecture, Ignore Rules (excluded supplier content) (+31 more)

### Community 9 - "OCR Platform Interface"
Cohesion: 0.07
Nodes (28): darwin/platform_ocr_darwin.dart, double get, File, List, bottom, boundingBox, bytes, dispose (+20 more)

### Community 10 - "FFI Type Aliases"
Cohesion: 0.10
Nodes (23): _In_, _In_opt_, OcrEngine, Pointer, instancetype, __darwin_pthread_t, OcrEngineHandle, wchar_t (+15 more)

### Community 11 - "Linux Flutter Shell"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 12 - "FFI Struct Types"
Cohesion: 0.09
Nodes (22): ffi.Struct, CMTime, CMTimeRange, __darwin_pthread_attr_t, __darwin_pthread_cond_t, __darwin_pthread_condattr_t, __darwin_pthread_handler_rec, __darwin_pthread_mutex_t (+14 more)

### Community 13 - "Docs & Packaging"
Cohesion: 0.15
Nodes (19): Self-Contained Windows Package, Municipal_Quotation_Builder_Setup.exe, Flutter, Municipal Quotation Builder, Self-Contained Windows Package (Release README), code_assets, ffi, package:image (+11 more)

### Community 14 - "Local Database"
Cohesion: 0.15
Nodes (12): Database?, all, _createSuggestionTable, _database, latest, LocalQuotationDatabase, save, suggestions (+4 more)

### Community 15 - "Windows Type Defs"
Cohesion: 0.15
Nodes (13): Int, __darwin_blksize_t, __darwin_ct_rune_t, __darwin_dev_t, __darwin_nl_item, __darwin_pid_t, __darwin_rune_t, __darwin_suseconds_t (+5 more)

### Community 16 - "App Tests"
Cohesion: 0.18
Nodes (8): package:flutter_test/flutter_test.dart, package:municipal_quotation_builder/import_service.dart, package:municipal_quotation_builder/main.dart, package:municipal_quotation_builder/quotation.dart, package:pdf/widgets.dart, main, main, main

### Community 17 - "Web Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 18 - "InnoSetup C# Example"
Cohesion: 0.31
Nodes (6): Mydll, DllExport, DllImport, IntPtr, String, Mydll

### Community 19 - "FFIgen Tooling"
Cohesion: 0.22
Nodes (7): dart:io, package:ffigen/ffigen.dart, config, main, result, config, main

### Community 20 - "OCR Package API"
Cohesion: 0.22
Nodes (7): package:platform_ocr/platform_ocr.dart, package:platform_ocr/src/platform_ocr_interface.dart, package:test/test.dart, src/platform_ocr_interface.dart, ocr, recognizeText, main

### Community 21 - "Windows Int Types"
Cohesion: 0.25
Nodes (8): Int64, int_fast64_t, int_least64_t, register_t, user_long_t, user_off_t, user_ssize_t, user_time_t

### Community 22 - "Darwin FS Types"
Cohesion: 0.25
Nodes (8): __darwin_fsblkcnt_t, __darwin_fsfilcnt_t, __darwin_mach_port_name_t, __darwin_mach_port_t, __darwin_natural_t, u_int32_t, __uint32_t, UnsignedInt

### Community 23 - "Darwin ID Types"
Cohesion: 0.25
Nodes (8): __darwin_gid_t, __darwin_id_t, __darwin_sigset_t, __darwin_socklen_t, __darwin_uid_t, __darwin_useconds_t, __darwin_wctype_t, __uint32_t

### Community 24 - "Pointer Types"
Cohesion: 0.29
Nodes (7): Long, __darwin_intptr_t, __darwin_ptrdiff_t, __darwin_ssize_t, __darwin_time_t, intmax_t, ptrdiff_t

### Community 25 - "Native Build Hooks"
Cohesion: 0.33
Nodes (5): package:code_assets/code_assets.dart, package:hooks/hooks.dart, package:native_toolchain_c/native_toolchain_c.dart, build, main

### Community 26 - "Windows Clock Types"
Cohesion: 0.33
Nodes (6): __darwin_clock_t, __darwin_pthread_key_t, __darwin_size_t, rsize_t, uintmax_t, UnsignedLong

### Community 27 - "OCR Example App"
Cohesion: 0.40
Nodes (4): imageFile, main, ocr, result

### Community 28 - "User Address Types"
Cohesion: 0.40
Nodes (5): syscall_arg_t, user_addr_t, user_size_t, user_ulong_t, u_int64_t

### Community 29 - "Opaque FFI Types"
Cohesion: 0.50
Nodes (4): ffi.Opaque, CGImage, __CVBuffer, opaqueCMSampleBuffer

### Community 30 - "Quotation Workspace State"
Cohesion: 0.50
Nodes (4): QuotationWorkspace, _QuotationWorkspaceState, State, StatefulWidget

### Community 31 - "64-bit Int Types"
Cohesion: 0.50
Nodes (4): LongLong, __darwin_blkcnt_t, __darwin_off_t, __int64_t

### Community 32 - "InnoSetup C Example"
Cohesion: 0.50
Nodes (3): HWND, UINT, MyDllFunc()

### Community 34 - "16-bit Int Types"
Cohesion: 0.67
Nodes (3): Int16, int_fast16_t, int_least16_t

### Community 35 - "32-bit Int Types"
Cohesion: 0.67
Nodes (3): Int32, int_fast32_t, int_least32_t

### Community 36 - "8-bit Int Types"
Cohesion: 0.67
Nodes (3): Int8, int_fast8_t, int_least8_t

### Community 37 - "App Widgets"
Cohesion: 0.67
Nodes (3): MunicipalQuotationApp, _SectionTitle, StatelessWidget

### Community 38 - "Inode Types"
Cohesion: 0.67
Nodes (3): __darwin_ino64_t, __darwin_ino_t, __uint64_t

### Community 39 - "Unsigned Short"
Cohesion: 0.67
Nodes (3): u_int16_t, __uint16_t, UnsignedShort

### Community 40 - "Unsigned Long Long"
Cohesion: 0.67
Nodes (3): u_int64_t, __uint64_t, UnsignedLongLong

### Community 41 - "Unsigned Char"
Cohesion: 0.67
Nodes (3): u_int8_t, __uint8_t, UnsignedChar

### Community 42 - "Fast 16-bit Types"
Cohesion: 0.67
Nodes (3): uint_fast16_t, uint_least16_t, Uint16

### Community 43 - "Fast 32-bit Types"
Cohesion: 0.67
Nodes (3): uint_fast32_t, uint_least32_t, Uint32

### Community 44 - "Fast 64-bit Types"
Cohesion: 0.67
Nodes (3): uint_fast64_t, uint_least64_t, Uint64

## Ambiguous Edges - Review These
- `Municipal Quotation Builder` → `Quotation Alignment Preview (PDF)`  [AMBIGUOUS]
  tmp/pdfs/quotation-alignment-preview.pdf · relation: conceptually_related_to

## Knowledge Gaps
- **547 isolated node(s):** `ExportService`, `_money`, `_pdfMoney`, `quantity`, `pdf` (+542 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Municipal Quotation Builder` and `Quotation Alignment Preview (PDF)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `_` connect `Darwin OCR Bindings` to `Core App Screens`, `Windows C Types`, `Export Service`, `FFI Type Aliases`, `FFI Struct Types`, `ObjC Runtime Types`, `Vision Request Types`, `Opaque FFI Types`?**
  _High betweenness centrality (0.434) - this node is a cross-community bridge._
- **Why does `OcrEngineHandle` connect `FFI Type Aliases` to `Windows C Types`?**
  _High betweenness centrality (0.193) - this node is a cross-community bridge._
- **Why does `FlutterWindow` connect `Windows Flutter Shell` to `macOS App Shell`?**
  _High betweenness centrality (0.105) - this node is a cross-community bridge._
- **Are the 2 inferred relationships involving `municipal_quotation_builder package` (e.g. with `Flutter Client Architecture` and `Municipal Quotation Builder`) actually correct?**
  _`municipal_quotation_builder package` has 2 INFERRED edges - model-reasoned connections that need verification._
- **What connects `ExportService`, `_money`, `_pdfMoney` to the rest of the system?**
  _547 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Darwin OCR Bindings` be split into smaller, more focused modules?**
  _Cohesion score 0.008097165991902834 - nodes in this community are weakly interconnected._