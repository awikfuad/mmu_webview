import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Alamat aplikasi web MMU (kiosk Dashboard Harian / frontend).
///
/// Ganti saat build dengan alamat yang bisa dijangkau TV melalui LAN/deployment:
///   flutter run --dart-define=APP_URL=http://192.168.1.50:5173
///   flutter build apk --release --dart-define=APP_URL=https://apps.mmu44.example
const String appUrl = String.fromEnvironment(
  'APP_URL',
  defaultValue: 'http://10.0.2.2:5173',
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
            if (mounted) setState(() => _loading = progress < 100);
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame != true) return;
            _retryTimer?.cancel();
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
    _controller.loadRequest(Uri.parse(appUrl));
  }

  /// Coba muat ulang otomatis supaya kiosk pulih sendiri saat server nyala kembali.
  void _scheduleRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _error = null;
        _loading = true;
      });
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
          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          if (_error != null) _ErrorOverlay(error: _error!, onRetry: _load),
        ],
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
    return Center(
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
    );
  }
}