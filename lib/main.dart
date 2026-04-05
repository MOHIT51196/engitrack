import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/controller.dart';
import 'src/screens/shell.dart';
import 'src/screens/splash_screen.dart';
import 'src/services.dart';
import 'src/storage.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool useSplash = kIsWeb || (!Platform.isAndroid);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: useSplash ? Brightness.light : Brightness.dark,
    ),
  );

  runApp(const EngiTrackApp());
}

class EngiTrackApp extends StatefulWidget {
  const EngiTrackApp({super.key});

  @override
  State<EngiTrackApp> createState() => _EngiTrackAppState();
}

class _EngiTrackAppState extends State<EngiTrackApp> {
  static bool get _useSplash => kIsWeb || (!Platform.isAndroid);

  EngiTrackController? _controller;
  late bool _showSplash = _useSplash;
  bool _splashAnimationDone = !_useSplash;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final AppStorage storage = AppStorage();
    final NotificationsService notificationsService = NotificationsService();
    final EngiTrackController controller = EngiTrackController(
      storage: storage,
      notificationsService: notificationsService,
    );
    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _controller = controller;
      if (_splashAnimationDone) _showSplash = false;
    });
    if (!_showSplash) _applyLightStatusBar();
  }

  void _onSplashComplete() {
    _splashAnimationDone = true;
    if (_controller == null) return;
    setState(() => _showSplash = false);
    _applyLightStatusBar();
  }

  void _applyLightStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  bool get _ready => _controller != null && !_showSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EngiTrack',
      debugShowCheckedModeBanner: false,
      theme: buildEngiTrackTheme(),
      builder: (BuildContext context, Widget? navigator) {
        if (_controller != null) {
          return EngiTrackScope(controller: _controller!, child: navigator!);
        }
        return navigator!;
      },
      home: _showSplash
          ? SplashScreen(onComplete: _onSplashComplete)
          : _ready
          ? const EngiTrackShell()
          : const _LoadingScreen(),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF6F6F9),
      body: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }
}
