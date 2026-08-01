# Graph Report - Quotation  (2026-08-01)

## Corpus Check
- 111 files · ~78,093 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1611 nodes · 2098 edges · 124 communities (79 shown, 45 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 57 edges (avg confidence: 0.81)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `cb4cbd9f`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

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
- iOS Bridging Header
- C# Project Example
- C# Solution Example
- Assembly Info Example
- Web Index
- core_implementations.cc
- DartProject
- BasicMessageChannel
- plugin_registrar.h
- export_service.dart
- string
- encodable_value.h
- PluginRegistrarWindows
- PluginRegistrar
- FlutterViewController
- FlutterView
- wWinMain
- flutter_engine.h
- GpuSurfaceTexture
- BinaryMessengerImpl
- .CallTopLevelWindowProcDelegates
- municipal_quotation_builder
- PixelBufferTexture
- handle_new_rx_page
- gradlew
- Pointer
- GeneratedPluginRegistrant
- bool get
- PackageDescription
- A4 Output Specification
- GetRegistrar
- ClearPlugins
- flutter_export_environment.sh
- flutter_export_environment.sh
- CHANGELOG.md
- Confidence Scoring
- Decimal Arithmetic Requirement
- Document Processing Service
- Extraction JSON Contract
- Flutter Client Architecture
- Ignore Rules (excluded supplier content)
- Line Extraction Rule
- Local Draft Autosave
- OCR & Document Detection Path
- Prompt Injection Resistance
- Quotation Data Model
- QuotationLine Model
- Riverpod State Management
- Extraction Review Mode
- Municipal Stamp/Signature Blocks
- Stamp/Signature Photograph (source reference)
- StampBlock Model
- Supplier Invoice PDF (source material)
- Tax Rules (18% material / 16% labour)
- Reusable Templates
- Title Extraction Rule
- Map
- String?
- Flutter
- Dart Native Assets
- ocr_cabi.cpp (C ABI wrapper)
- PlatformOcr API
- Tesseract OCR
- Vision.framework
- Windows.Media.Ocr (WinRT)

## God Nodes (most connected - your core abstractions)
1. `DartProject` - 25 edges
2. `FlutterEngine` - 24 edges
3. `Win32Window` - 22 edges
4. `MethodCodec` - 19 edges
5. `BinaryMessenger` - 17 edges
6. `PluginRegistrarWindows` - 16 edges
7. `PluginRegistrar` - 15 edges
8. `ByteBufferStreamWriter` - 14 edges
9. `FlutterViewController` - 14 edges
10. `BasicMessageChannel` - 13 edges

## Surprising Connections (you probably didn't know these)
- `Quotation Alignment Preview (PDF)` --conceptually_related_to--> `municipal_quotation_builder`  [AMBIGUOUS]
  tmp/pdfs/quotation-alignment-preview.pdf → README.md
- `A4 Output Specification` --conceptually_related_to--> `quotation-verification.pdf (output artifact)`  [INFERRED]
  Municipal_Quotation_Builder_PRD.md → output/pdf/quotation-verification.pdf
- `A4 Output Specification` --conceptually_related_to--> `quotation-monochrome-preview.pdf (output artifact)`  [INFERRED]
  Municipal_Quotation_Builder_PRD.md → tmp/pdfs/quotation-monochrome-preview.pdf
- `google_mlkit_text_recognition` --semantically_similar_to--> `platform_ocr plugin`  [INFERRED] [semantically similar]
  pubspec.yaml → third_party/platform_ocr/CHANGELOG.md
- `quotation-verification.pdf (output artifact)` --semantically_similar_to--> `quotation-monochrome-preview.pdf (output artifact)`  [INFERRED] [semantically similar]
  output/pdf/quotation-verification.pdf → tmp/pdfs/quotation-monochrome-preview.pdf

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **PDF Extraction Pipeline** — municipal_quotation_builder_prd_supplier_invoice_pdf, municipal_quotation_builder_prd_ocr_path, municipal_quotation_builder_prd_title_extraction_rule, municipal_quotation_builder_prd_line_extraction_rule, municipal_quotation_builder_prd_extraction_json_contract [EXTRACTED 1.00]
- **A4 Quotation Generation Flow** — municipal_quotation_builder_prd_a4_output_spec, municipal_quotation_builder_prd_stamp_blocks, pubspec_pdf_package, pubspec_printing_package, output_pdf_quotation_verification [EXTRACTED 1.00]
- **Quotation Data Model** — municipal_quotation_builder_prd_quotation_data_model, municipal_quotation_builder_prd_quotationline, municipal_quotation_builder_prd_stampblock_model, municipal_quotation_builder_prd_tax_rules [EXTRACTED 1.00]
- **platform_ocr Cross-Platform Native OCR Architecture** — third_party_platform_ocr_readme_platform_ocr, third_party_platform_ocr_readme_windows_media_ocr, third_party_platform_ocr_readme_vision_framework, third_party_platform_ocr_readme_ocr_cabi, third_party_platform_ocr_pubspec_image [EXTRACTED 0.95]
- **Municipal Quotation Builder Windows Distribution** — readme_municipal_quotation_builder, installer_portable_readme_self_contained_windows_package, installer_portable_readme_setup_exe [INFERRED 0.85]

## Communities (124 total, 45 thin omitted)

### Community 0 - "Darwin OCR Bindings"
Cohesion: 0.01
Nodes (248): >, CGPoint, CGRect, _, external CMTime, ObjCObjectImpl>, alloc, allocWithZone (+240 more)

### Community 1 - "Core App Screens"
Cohesion: 0.02
Nodes (97): dart:async, export_service.dart, import_service.dart, _addOrEditLine, _autosave, _beginOperation, _bottomActions, build (+89 more)

### Community 2 - "Windows C Types"
Cohesion: 0.03
Nodes (61): Array, external, external int, __arg, __cleanup_stack, Dart__darwin_clock_t, Dart__darwin_ct_rune_t, Dart__darwin_fsblkcnt_t (+53 more)

### Community 3 - "Windows Flutter Shell"
Cohesion: 0.07
Nodes (49): Point, Size, HWND, LPARAM, LRESULT, UINT, WPARAM, FlutterWindow (+41 more)

### Community 4 - "Quotation Model"
Cohesion: 0.04
Nodes (52): DateTime?, int get, amountMinor, cleaned, copy, createdAt, customStampIsVisible, customStamps (+44 more)

### Community 5 - "macOS App Shell"
Cohesion: 0.06
Nodes (29): Cocoa, file_picker, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterMacOS, FlutterPluginRegistry (+21 more)

### Community 6 - "Export Service"
Cohesion: 0.11
Nodes (21): bindings.g.dart, dart:ffi, dart:typed_data, package:ffi/ffi.dart, package:image/image.dart, package:objective_c/objective_c.dart, ../platform_ocr_interface.dart, DarwinPlatformOcr (+13 more)

### Community 7 - "Import Service"
Cohesion: 0.04
Nodes (44): _capitalise, _category, centerX, centerY, cleanImportedDescription, cleanImportedTitle, _combine, copyWith (+36 more)

### Community 8 - "PRD Spec & Design"
Cohesion: 0.18
Nodes (13): analysis_options.yaml (flutter_lints), pubspec.yaml (package manifest), file_picker package, google_mlkit_text_recognition, municipal_quotation_builder package, pdf package, platform_ocr (path dependency), printing package (+5 more)

### Community 9 - "OCR Platform Interface"
Cohesion: 0.07
Nodes (28): darwin/platform_ocr_darwin.dart, double get, File, List, bottom, boundingBox, bytes, dispose (+20 more)

### Community 10 - "FFI Type Aliases"
Cohesion: 0.21
Nodes (11): OcrEngine, OcrEngineHandle, wchar_t, wstring, CreateOcrEngine(), EscapeJsonString(), FreeOcrEngine(), FreeOcrResult() (+3 more)

### Community 11 - "Linux Flutter Shell"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 12 - "FFI Struct Types"
Cohesion: 0.09
Nodes (22): ffi.Struct, CMTime, CMTimeRange, __darwin_pthread_attr_t, __darwin_pthread_cond_t, __darwin_pthread_condattr_t, __darwin_pthread_handler_rec, __darwin_pthread_mutex_t (+14 more)

### Community 13 - "Docs & Packaging"
Cohesion: 0.11
Nodes (18): code_assets, ffi, package:image, native_toolchain_c, objective_c, platform_ocr (pubspec declaration), Darwin (iOS/macOS), Features (+10 more)

### Community 14 - "Local Database"
Cohesion: 0.06
Nodes (32): Database?, all, _createQuotationTable, _createReferenceTable, _createSettingsTable, _createSuggestionTable, _database, _databasePath (+24 more)

### Community 15 - "Windows Type Defs"
Cohesion: 0.15
Nodes (13): Int, __darwin_blksize_t, __darwin_ct_rune_t, __darwin_dev_t, __darwin_nl_item, __darwin_pid_t, __darwin_rune_t, __darwin_suseconds_t (+5 more)

### Community 16 - "App Tests"
Cohesion: 0.13
Nodes (12): dart:convert, package:flutter_test/flutter_test.dart, package:municipal_quotation_builder/export_service.dart, package:municipal_quotation_builder/import_service.dart, package:municipal_quotation_builder/main.dart, package:municipal_quotation_builder/quotation.dart, package:pdf/widgets.dart, main (+4 more)

### Community 17 - "Web Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 18 - "InnoSetup C# Example"
Cohesion: 0.06
Nodes (43): EncodedType, ByteBufferStreamReader, bytes_, location_, size_, ByteBufferStreamWriter, bytes_, ByteStreamReader (+35 more)

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
Cohesion: 0.06
Nodes (33): MethodCallHandler, BinaryMessenger, Send, SetMessageHandler, EventChannel, codec_, messenger_, name_ (+25 more)

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

### Community 45 - "InnoSetup Delphi Example"
Cohesion: 0.04
Nodes (39): nanoseconds, FlutterDesktopEngineRef, FlutterDesktopPluginRegistrarRef, function, HWND, LPARAM, LRESULT, optional (+31 more)

### Community 55 - "iOS Bridging Header"
Cohesion: 0.40
Nodes (3): GeneratedPluginRegistrant, +registerWithRegistry, NSObject

### Community 57 - "C# Project Example"
Cohesion: 0.05
Nodes (42): 10.1 Quotation, 10.2 QuotationLine, 10.3 StampBlock, 10. Data Model, 11.1 Required screens, 11. UX and Visual Design, 12. A4 Output Specification, 13.1 Flutter client (+34 more)

### Community 58 - "C# Solution Example"
Cohesion: 0.08
Nodes (27): ResultHandlerError, ResultHandlerNotImplemented, ResultHandlerSuccess, vector, ReplyManager::SendResponseData(), EngineMethodResult, codec_, reply_manager_ (+19 more)

### Community 59 - "Assembly Info Example"
Cohesion: 0.09
Nodes (26): StreamHandlerCancel, StreamHandlerListen, EncodableValue, EventSink, EndOfStreamInternal, ErrorInternal, SuccessInternal, string (+18 more)

### Community 61 - "core_implementations.cc"
Cohesion: 0.06
Nodes (32): FlutterDesktopMessage, TextureVariant, BinaryMessengerImpl::BinaryMessengerImpl(), BinaryMessengerImpl::Send(), BinaryMessengerImpl::SetMessageHandler(), BinaryMessageHandler, BinaryReply, FlutterDesktopMessengerRef (+24 more)

### Community 62 - "DartProject"
Cohesion: 0.08
Nodes (22): AccessibilityMode, GpuPreference, UIThreadPolicy, FlutterViewId, HWND, LPARAM, LRESULT, optional (+14 more)

### Community 63 - "BasicMessageChannel"
Cohesion: 0.10
Nodes (19): MessageHandler, BasicMessageChannel, codec_, messenger_, name_, BinaryReply, string, T (+11 more)

### Community 64 - "plugin_registrar.h"
Cohesion: 0.12
Nodes (12): map, Plugin, PluginRegistrarManager, GetInstance, OnRegistrarDestroyed, FlutterDesktopPluginRegistrarRef, unique_ptr, PluginRegistrar::AddPlugin() (+4 more)

### Community 65 - "export_service.dart"
Cohesion: 0.09
Nodes (21): csv, download, excel, ExportService, _money, pdf, _pdfMoney, printPdf (+13 more)

### Community 66 - "string"
Cohesion: 0.22
Nodes (8): string, vector, EncodableValue, EncodableValue, EncodableValue, EncodableValue, EncodableValue, EncodableValue

### Community 67 - "encodable_value.h"
Cohesion: 0.15
Nodes (8): EncodableValueVariant, partial_ordering, CustomEncodableValue, value_, EncodableValue, any, T, operator<=>()

### Community 68 - "PluginRegistrarWindows"
Cohesion: 0.19
Nodes (9): WindowProcDelegate, FlutterViewId, map, shared_ptr, unique_ptr, PluginRegistrarWindows, implicit_view_, next_window_proc_delegate_id_ (+1 more)

### Community 69 - "PluginRegistrar"
Cohesion: 0.18
Nodes (9): set, unique_ptr, PluginRegistrar, AddPlugin, plugins_, TextureRegistrar, MarkTextureFrameAvailable, RegisterTexture (+1 more)

### Community 70 - "FlutterViewController"
Cohesion: 0.20
Nodes (8): FlutterDesktopViewControllerRef, FlutterViewController, controller_, ForceRedraw, HandleTopLevelWindowProc, view_id, shared_ptr, unique_ptr

### Community 71 - "FlutterView"
Cohesion: 0.22
Nodes (5): FlutterDesktopViewRef, FlutterView, view_, HWND, IDXGIAdapter

### Community 72 - "wWinMain"
Cohesion: 0.27
Nodes (9): _In_, _In_opt_, wWinMain(), string, vector, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 74 - "GpuSurfaceTexture"
Cohesion: 0.39
Nodes (5): FlutterDesktopGpuSurfaceDescriptor, FlutterDesktopGpuSurfaceType, ObtainDescriptorCallback, GpuSurfaceTexture, obtain_descriptor_callback_

### Community 75 - "BinaryMessengerImpl"
Cohesion: 0.25
Nodes (7): BinaryMessengerImpl, handlers_, messenger_, Send, SetMessageHandler, BinaryMessageHandler, FlutterDesktopMessengerRef

### Community 76 - ".CallTopLevelWindowProcDelegates"
Cohesion: 0.43
Nodes (6): HWND, LPARAM, LRESULT, optional, UINT, WPARAM

### Community 77 - "municipal_quotation_builder"
Cohesion: 0.38
Nodes (6): Self-Contained Windows Package, Municipal_Quotation_Builder_Setup.exe, Getting Started, municipal_quotation_builder, Self-Contained Windows Package (Release README), Quotation Alignment Preview (PDF)

### Community 78 - "PixelBufferTexture"
Cohesion: 0.47
Nodes (4): CopyBufferCallback, FlutterDesktopPixelBuffer, PixelBufferTexture, copy_buffer_callback_

### Community 79 - "handle_new_rx_page"
Cohesion: 0.33
Nodes (5): handle_new_rx_page(), __lldb_init_module(), Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages., SBDebugger, SBFrame

### Community 80 - "gradlew"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 81 - "Pointer"
Cohesion: 0.40
Nodes (5): Pointer, instancetype, __builtin_va_list, __darwin_pthread_t, __darwin_va_list

### Community 83 - "bool get"
Cohesion: 0.50
Nodes (3): bool get, Awesome, isAwesome

### Community 86 - "A4 Output Specification"
Cohesion: 1.00
Nodes (3): A4 Output Specification, quotation-verification.pdf (output artifact), quotation-monochrome-preview.pdf (output artifact)

### Community 87 - "GetRegistrar"
Cohesion: 0.67
Nodes (3): GetRegistrar(), FlutterDesktopPluginRegistrarRef, T

## Ambiguous Edges - Review These
- `municipal_quotation_builder` → `Quotation Alignment Preview (PDF)`  [AMBIGUOUS]
  tmp/pdfs/quotation-alignment-preview.pdf · relation: conceptually_related_to

## Knowledge Gaps
- **758 isolated node(s):** `flutter_export_environment.sh script`, `+registerWithRegistry`, `ExportService`, `_money`, `_pdfMoney` (+753 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **45 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `municipal_quotation_builder` and `Quotation Alignment Preview (PDF)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `OcrEngineHandle` connect `FFI Type Aliases` to `Pointer`, `Windows C Types`?**
  _High betweenness centrality (0.344) - this node is a cross-community bridge._
- **What connects `Intercept NOTIFY_DEBUGGER_ABOUT_RX_PAGES and touch the pages.`, `flutter_export_environment.sh script`, `+registerWithRegistry` to the rest of the system?**
  _764 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Darwin OCR Bindings` be split into smaller, more focused modules?**
  _Cohesion score 0.008032128514056224 - nodes in this community are weakly interconnected._
- **Should `Core App Screens` be split into smaller, more focused modules?**
  _Cohesion score 0.02040816326530612 - nodes in this community are weakly interconnected._
- **Should `Windows C Types` be split into smaller, more focused modules?**
  _Cohesion score 0.03278688524590164 - nodes in this community are weakly interconnected._
- **Should `Windows Flutter Shell` be split into smaller, more focused modules?**
  _Cohesion score 0.07127882599580712 - nodes in this community are weakly interconnected._