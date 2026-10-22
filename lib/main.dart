import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:zerobit_player/src/rust/frb_generated.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'core/utils/memory_manager.dart';

class CustomHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..userAgent =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36';
  }
}

void main() async {
  await checkInstance();

  HttpOverrides.global = CustomHttpOverrides();

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await RustLib.init();

  await initLog();
  initResourceLimit();

  await initBassSupport();
  await initSmtcSupport();

  await initHive();
  await initDependency();
  await initWindow();

  initDebugOption();
  runApp(const MainFrame());

  loadAudioResource();

  await initStream();
  initTaskbar();

  MemoryManager.startLoopTrim('Loop');
}
