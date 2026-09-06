import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const String appUrl = String.fromEnvironment(
  'APP_URL',
  defaultValue: 'https://mmu-new-frontend.vercel.app/',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KioskApp());
}

class KioskApp extends StatelessWidget {
  const KioskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MMU TV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const KioskWebView(),
    );
  }
}

class KioskWebView extends StatefulWidget {
  const KioskWebView({super.key});

  @override
  State<KioskWebView> createState() => _KioskWebViewState();
}

class _KioskWebViewState extends State<KioskWebView> {
  late final WebViewController _controller;
  bool _loading = true;
  int _loadingProgress = 0; // Menyimpan status persentase loading (0-100)
  String? _error;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF00352C))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted && _error == null) {
              setState(() {
                _loadingProgress = progress;
                _loading = progress < 100;
              });
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _loading = true;
                _loadingProgress = 0;
                _error = null;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _loading = false;
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (error) {
            final isMainFrame = error.isForMainFrame ?? true;
            if (!isMainFrame) return;

            if (mounted) {
              setState(() {
                _error = error.description.isEmpty
                    ? 'Gagal memuat $appUrl'
                    : error.description;
                _loading = false;
              });
            }
            _scheduleRetry();
          },
        ),
      );
    _load();
  }

  void _load() {
    _retryTimer?.cancel();
    if (mounted) {
      setState(() {
        _error = null;
        _loading = true;
        _loadingProgress = 0;
      });
    }
    _controller.loadRequest(Uri.parse(appUrl));
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00352C),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          
          // Progress Bar tipis di bagian paling atas
          if (_loading && _error == null)
            Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(
                value: _loadingProgress / 100,
                minHeight: 4,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              ),
            ),

          // Tampilan Informasi Loading & Persentase di tengah layar
          if (_loading && _error == null)
            _LoadingOverlay(progress: _loadingProgress),

          if (_error != null) _ErrorOverlay(error: _error!, onRetry: _load),

          // Tombol Settings untuk akses tanpa remote (klik mouse)
          Align(
            alignment: Alignment.bottomRight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton.filledTonal(
                  tooltip: 'Buka Pengaturan',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                    iconSize: 28,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    const intent = AndroidIntent(
      action: 'android.settings.SETTINGS',
    );
    intent.launch();
  }
}

/// Widget Overlay untuk menampilkan animasi Putaran (Spinner) dan Persentase Loading
class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay({required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF00352C), // Background solid agar web yang setengah muat tidak terlihat berantakan
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.tealAccent),
            ),
            const SizedBox(height: 20),
            Text(
              'Memuat MMU TV... $progress%',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF00352C),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tv_off, size: 72, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              'Tidak dapat terhubung ke server MMU',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}