import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/app_colors.dart';
import '../widgets/no_internet_view.dart';

/// Generic in-app browser used for both the Privacy Policy and Support
/// pages, with a friendly "no internet" fallback using the supplied art.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _hasConnection = true;
  bool _loadFailed = false;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.night)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress / 100),
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _loadFailed = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() {
            _loadFailed = true;
            _isLoading = false;
          }),
        ),
      );
    _checkAndLoad();
  }

  Future<void> _checkAndLoad() async {
    final results = await Connectivity().checkConnectivity();
    final connected = !results.contains(ConnectivityResult.none);
    setState(() {
      _hasConnection = connected;
      _loadFailed = false;
    });
    if (connected) {
      setState(() => _isLoading = true);
      await _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final showNoInternet = !_hasConnection || _loadFailed;
    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: AppBar(
        backgroundColor: AppColors.nightDeep,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: showNoInternet
          ? NoInternetView(onRetry: _checkAndLoad)
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress,
                    color: AppColors.gold,
                    backgroundColor: Colors.transparent,
                  ),
              ],
            ),
    );
  }
}
