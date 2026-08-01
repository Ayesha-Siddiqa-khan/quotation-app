import 'package:code_assets/code_assets.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final target = input.config.code.targetOS;
    final isDarwin = target == OS.macOS || target == OS.iOS;
    final isWindows = target == OS.windows;
    if (!isDarwin && !isWindows) return;
    final packageName = input.packageName;
    final cbuilder = CBuilder.library(
      name: packageName,
      assetName: isDarwin
          ? 'src/darwin/bindings.g.dart'
          : isWindows
              ? 'src/windows/bindings.g.dart'
              : null,
      sources: [
        if (isDarwin) 'src/darwin/bindings.g.m',
        if (isWindows) 'src/windows/ocr_cabi.cpp',
      ],
      includes: [
        if (isDarwin) 'src/darwin',
        if (isWindows) 'src/windows',
      ],
      frameworks: [
        if (isDarwin) 'Vision',
        if (isDarwin) 'Foundation',
      ],
      libraries: [
        if (isWindows) 'windowsapp',
      ],
      flags: [
        if (isDarwin) '-fobjc-arc',
        if (isWindows) '/std:c++17',
        if (isWindows) '/EHsc',
      ],
    );
    await cbuilder.run(
      input: input,
      output: output,
    );
  });
}
