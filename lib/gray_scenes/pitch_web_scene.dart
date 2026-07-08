import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../net_core/geared_client.dart';
import '../net_core/keep_box.dart';
import '../net_core/net_pulse.dart';
import '../net_core/whistle_alert.dart';
import 'offline_pitch_scene.dart';

// ============================================================
// PITCH WEB SCENE — immersive WebView (gray content)
// ============================================================
// Hosts the content URL with: forged device UA, both orientations,
// immersive system UI, external-scheme hand-off, redirect-loop recovery,
// live connectivity guard, warm push URL loading, file uploads,
// third-party cookies, media autoplay and safe-area / keyboard JS fixes.
//
// Landscape SafeArea is applied on the top+sides ONLY — the WebView
// never crawls under a camera cutout even in landscape mode.
// ============================================================

class PitchWebScene extends StatefulWidget {
  const PitchWebScene({
    super.key,
    required this.contentUrl,
    required this.box,
    required this.alert,
    required this.pulse,
  });

  final String contentUrl;
  final KeepBox box;
  final WhistleAlert alert;
  final NetPulse pulse;

  @override
  State<PitchWebScene> createState() => _PitchWebSceneState();
}

class _PitchWebSceneState extends State<PitchWebScene>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinning = true;
  bool _offlineOpened = false;
  String? _lastMainFrame;
  int _redirectRetries = 0;
  Timer? _offlineDebounce;
  StreamSubscription<List<ConnectivityResult>>? _pulseSub;

  static const MethodChannel _uploadChannel =
      MethodChannel('goalrush.pitch/upload');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _enterImmersive();
    _wireController();

    widget.alert.onUrl = (String url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };

    _pulseSub = widget.pulse.pulses.listen((List<ConnectivityResult> r) {
      if (r.isEmpty) return;
      final bool allNone =
          r.every((ConnectivityResult e) => e == ConnectivityResult.none);
      if (!allNone) {
        _offlineDebounce?.cancel();
        return;
      }
      _offlineDebounce?.cancel();
      // Debounce to absorb VPN transitions that briefly report `none`.
      _offlineDebounce =
          Timer(const Duration(milliseconds: 700), _openOffline);
    });
  }

  void _enterImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _enterImmersive();
  }

  void _wireController() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(stadiumWire.userAgent)
      ..setBackgroundColor(Colors.black)
      ..enableZoom(false)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinning = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinning = false);
          _redirectRetries = 0;
          _neutraliseSafeArea();
          _keyboardScrollGuard();
        },
        onWebResourceError: (WebResourceError err) {
          if (err.isForMainFrame != true) return;
          final String d = err.description.toLowerCase();
          final bool loop = d.contains('too_many_redirects') ||
              d.contains('too many redirects') ||
              err.errorCode == -1007 ||
              err.errorCode == -9;
          if (loop && _lastMainFrame != null && _redirectRetries < 3) {
            _redirectRetries++;
            _web.loadRequest(Uri.parse(_lastMainFrame!));
            return;
          }
          // Cover the WebView with our spinner right away so Android's
          // native error page (black robot) never flashes through.
          if (mounted) setState(() => _spinning = true);
          final bool obviouslyOffline = d.contains('name_not_resolved') ||
              d.contains('internet_disconnected') ||
              d.contains('network_changed') ||
              err.errorCode == -105 ||
              err.errorCode == -106 ||
              err.errorCode == -21;
          if (obviouslyOffline) {
            _openOffline();
          } else {
            _maybeOpenOffline();
          }
        },
        onNavigationRequest: (NavigationRequest req) {
          final Uri? uri = Uri.tryParse(req.url);
          if (uri == null) return NavigationDecision.prevent;
          const Set<String> inApp = <String>{
            'http',
            'https',
            'about',
            'data',
            'blob',
          };
          if (inApp.contains(uri.scheme)) {
            if (req.isMainFrame) _lastMainFrame = req.url;
            return NavigationDecision.navigate;
          }
          _handOffToOs(uri);
          return NavigationDecision.prevent;
        },
      ));

    _tuneAndroid();
    _web.loadRequest(Uri.parse(widget.contentUrl));
  }

  void _tuneAndroid() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final AndroidWebViewController a =
        _web.platform as AndroidWebViewController;

    a.setMediaPlaybackRequiresUserGesture(false);

    a.setOnPlatformPermissionRequest(
      (PlatformWebViewPermissionRequest req) => req.grant(),
    );

    a.setOnShowFileSelector(_pickFiles);

    final AndroidWebViewCookieManager cookies = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookies.setAcceptThirdPartyCookies(a, true);
  }

  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    try {
      final List<Object?>? picked = await _uploadChannel
          .invokeMethod<List<Object?>>('pick', <String, Object>{
        'multiple': params.mode == FileSelectorMode.openMultiple,
        'mimeTypes': params.acceptTypes
            .where((String t) => t.trim().isNotEmpty)
            .toList(),
      });
      if (picked == null) return const <String>[];
      return picked.whereType<String>().toList();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> _handOffToOs(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // Probe-then-show: used for WebView load errors that may be transient.
  Future<void> _maybeOpenOffline() async {
    if (_offlineOpened) return;
    final bool online = await widget.pulse.isReachable();
    if (online) return;
    _openOffline();
  }

  // Immediately swaps to the offline screen. Retry rebuilds the WebView
  // at the last known main-frame URL.
  void _openOffline() {
    if (_offlineOpened || !mounted) return;
    _offlineOpened = true;
    final String current = _lastMainFrame ?? widget.contentUrl;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => OfflinePitchScene(
          onRetryBuild: (_) => PitchWebScene(
            contentUrl: current,
            box: widget.box,
            alert: widget.alert,
            pulse: widget.pulse,
          ),
        ),
      ),
    );
  }

  // Scrolls focused inputs above the keyboard. `behavior:'auto'` +
  // single delayed pass to avoid fighting the keyboard animation
  // (see .cursor/rules/android_gray_guide.md §"Android bugs" §3).
  void _keyboardScrollGuard() {
    _web.runJavaScript(r'''
(function(){
  if (window.__grKb) return; window.__grKb = true;
  function isField(el){return el&&(el.tagName==='INPUT'||el.tagName==='TEXTAREA'||el.isContentEditable);}
  function bring(){
    var el=document.activeElement; if(!isField(el))return;
    var vp=window.visualViewport;
    if(vp){
      var r=el.getBoundingClientRect(); var bottom=vp.offsetTop+vp.height;
      if(r.bottom>bottom-20||r.top<vp.offsetTop){el.scrollIntoView({behavior:'auto',block:'nearest'});}
    } else { el.scrollIntoView({behavior:'auto',block:'nearest'}); }
  }
  document.addEventListener('focusin',function(e){ if(isField(e.target)) setTimeout(bring,350); });
  if(window.visualViewport){
    var prev=window.visualViewport.height;
    window.visualViewport.addEventListener('resize',function(){
      var h=window.visualViewport.height; if(h<prev) setTimeout(bring,120); prev=h;
    });
  }
})();
''');
  }

  // Neutralises the site's safe-area insets ONLY (not html/body/#app
  // padding — see .cursor/rules/webview_safe_area_injection.mdc).
  // Suspends while the keyboard is open to avoid layout races.
  void _neutraliseSafeArea() {
    _web.runJavaScript(r'''
(function(){
  if(window.__grSa) return; window.__grSa=true;
  var ID='__gr_sa';
  var CSS=':root{--safe-area-inset-top:0px!important;--safe-area-inset-right:0px!important;'
    +'--safe-area-inset-bottom:0px!important;--safe-area-inset-left:0px!important;'
    +'--sat:0px!important;--sar:0px!important;--sab:0px!important;--sal:0px!important;'
    +'--safe-top:0px!important;--safe-bottom:0px!important;'
    +'--safe-left:0px!important;--safe-right:0px!important;}'
    +'.gameview-mobile-header,.app-header,.js-safe-top{padding-top:0!important;margin-top:0!important;}';
  function kbOpen(){ if(!window.visualViewport)return false; return window.visualViewport.height<window.innerHeight*0.75; }
  function apply(){
    if(kbOpen())return;
    var head=document.head||document.documentElement; if(!head)return;
    var m=document.querySelector('meta[name="viewport"]');
    if(m && !/viewport-fit\s*=\s*contain/i.test(m.getAttribute('content')||'')){
      var c=(m.getAttribute('content')||'').replace(/,?\s*viewport-fit\s*=\s*\w+/ig,'').trim();
      m.setAttribute('content', c+(c?', ':'')+'viewport-fit=contain');
    }
    var s=document.getElementById(ID);
    if(!s){ s=document.createElement('style'); s.id=ID; head.appendChild(s); }
    if(s.textContent!==CSS) s.textContent=CSS;
  }
  apply();
  ['pushState','replaceState'].forEach(function(fn){
    var o=history[fn]; history[fn]=function(){var r=o.apply(this,arguments); setTimeout(apply,80); setTimeout(apply,400); return r;};
  });
  window.addEventListener('popstate',function(){setTimeout(apply,80);});
  setInterval(apply,2500);
})();
''');
  }

  Future<void> _handleBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseSub?.cancel();
    _offlineDebounce?.cancel();
    widget.alert.onUrl = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final Orientation orient = mq.orientation;
    // Landscape: pad both sides + top for the notch. Portrait: only top.
    final EdgeInsets safe = orient == Orientation.landscape
        ? EdgeInsets.only(
            left: mq.viewPadding.left,
            right: mq.viewPadding.right,
            top: mq.viewPadding.top,
          )
        : EdgeInsets.only(top: mq.viewPadding.top);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: safe,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinning)
              const ColoredBox(
                color: Color(0x99000000),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFFFFD770)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
