import 'package:app_settings/app_settings.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/app_theme.dart';
import '../bible/bible_browser_view.dart';

class BibleProjectBrowserView extends StatefulWidget {
  final String initialUrl;

  const BibleProjectBrowserView({
    super.key,
    this.initialUrl = 'https://bibleproject.com/bible/nasb/genesis/1/',
  });

  /// Returns a page route that slides up from the bottom on all platforms.
  static PageRoute<void> route({String? initialUrl}) {
    return PageRouteBuilder<void>(
      fullscreenDialog: true,
      pageBuilder: (_, _, _) => BibleProjectBrowserView(
        initialUrl: initialUrl ?? 'https://bibleproject.com/bible/nasb/genesis/1/',
      ),
      transitionsBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  /// Converts a human-readable reference like "Romans 8:28" or
  /// "1 Corinthians 13:4" into a BibleProject chapter URL.
  /// Falls back to Genesis 1 if the reference cannot be parsed.
  static String urlFromReference(String reference) {
    final lastSpace = reference.lastIndexOf(' ');
    if (lastSpace < 0) return 'https://bibleproject.com/bible/nasb/genesis/1/';
    final book = reference.substring(0, lastSpace).trim().toLowerCase();
    final chapterVerse = reference.substring(lastSpace + 1);
    final chapter = chapterVerse.split(':').first.trim();
    final slug = _kBookSlugs[book] ?? book.replaceAll(' ', '-');
    return 'https://bibleproject.com/bible/nasb/$slug/$chapter/';
  }

  /// Opens BibleProject if online. If offline, shows a dialog offering to
  /// open phone Wi-Fi settings or fall back to the offline Bible at the same
  /// [reference] (e.g. "Romans 8:28"). Pass null to open at the default page.
  static Future<void> openOrPrompt(BuildContext context, {String? reference}) async {
    final results = await Connectivity().checkConnectivity();
    final isOffline = results.every((r) => r == ConnectivityResult.none);

    if (!context.mounted) return;

    if (!isOffline) {
      final url = reference != null ? urlFromReference(reference) : null;
      Navigator.push<void>(context, route(initialUrl: url));
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: GraceWayColor.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'You\'re offline',
          style: TextStyle(color: GraceWayColor.warmWhite, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'BibleProject Bible requires an internet connection. You can connect to Wi-Fi or read the offline Bible instead.',
          style: TextStyle(color: GraceWayColor.warmWhite, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              AppSettings.openAppSettings(type: AppSettingsType.wifi);
            },
            child: const Text('Open Settings', style: TextStyle(color: GraceWayColor.softGold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => BibleBrowserView(initialReference: reference),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: GraceWayColor.golden,
              foregroundColor: GraceWayColor.charcoal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Read Offline', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  State<BibleProjectBrowserView> createState() =>
      _BibleProjectBrowserViewState();
}

// Maps lowercase book names (including common variants) to BibleProject slugs.
const Map<String, String> _kBookSlugs = {
  // ── Old Testament ──────────────────────────────────────────────────────────
  'genesis': 'genesis',
  'exodus': 'exodus',
  'leviticus': 'leviticus',
  'numbers': 'numbers',
  'deuteronomy': 'deuteronomy',
  'joshua': 'joshua',
  'judges': 'judges',
  'ruth': 'ruth',
  '1 samuel': '1-samuel',
  '2 samuel': '2-samuel',
  '1 kings': '1-kings',
  '2 kings': '2-kings',
  '1 chronicles': '1-chronicles',
  '2 chronicles': '2-chronicles',
  'ezra': 'ezra',
  'nehemiah': 'nehemiah',
  'esther': 'esther',
  'job': 'job',
  'psalm': 'psalms',
  'psalms': 'psalms',
  'proverbs': 'proverbs',
  'ecclesiastes': 'ecclesiastes',
  'song of solomon': 'song-of-songs',
  'song of songs': 'song-of-songs',
  'isaiah': 'isaiah',
  'jeremiah': 'jeremiah',
  'lamentations': 'lamentations',
  'ezekiel': 'ezekiel',
  'daniel': 'daniel',
  'hosea': 'hosea',
  'joel': 'joel',
  'amos': 'amos',
  'obadiah': 'obadiah',
  'jonah': 'jonah',
  'micah': 'micah',
  'nahum': 'nahum',
  'habakkuk': 'habakkuk',
  'zephaniah': 'zephaniah',
  'haggai': 'haggai',
  'zechariah': 'zechariah',
  'malachi': 'malachi',
  // ── New Testament ──────────────────────────────────────────────────────────
  'matthew': 'matthew',
  'mark': 'mark',
  'luke': 'luke',
  'john': 'john',
  'acts': 'acts',
  'romans': 'romans',
  '1 corinthians': '1-corinthians',
  '2 corinthians': '2-corinthians',
  'galatians': 'galatians',
  'ephesians': 'ephesians',
  'philippians': 'philippians',
  'colossians': 'colossians',
  '1 thessalonians': '1-thessalonians',
  '2 thessalonians': '2-thessalonians',
  '1 timothy': '1-timothy',
  '2 timothy': '2-timothy',
  'titus': 'titus',
  'philemon': 'philemon',
  'hebrews': 'hebrews',
  'james': 'james',
  '1 peter': '1-peter',
  '2 peter': '2-peter',
  '1 john': '1-john',
  '2 john': '2-john',
  '3 john': '3-john',
  'jude': 'jude',
  'revelation': 'revelation',
};

class _BibleProjectBrowserViewState extends State<BibleProjectBrowserView> {

  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _loadingProgress = progress / 100);
          },
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            // Only treat main-frame errors as a full page failure.
            if (error.isForMainFrame ?? true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Widget _buildOfflinePlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No internet connection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: GraceWayColor.warmWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'BibleProject requires an internet connection. Connect and tap Retry.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _controller.reload(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GraceWayColor.golden,
                foregroundColor: GraceWayColor.charcoal,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GraceWayColor.charcoal,
      appBar: AppBar(
        backgroundColor: GraceWayColor.charcoal,
        foregroundColor: GraceWayColor.warmWhite,
        elevation: 0,
        title: Row(
          children: [
            Opacity(
              opacity: 0.85,
              child: Image.asset('assets/BP_logo_wht.webp', height: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Bible',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: GraceWayColor.warmWhite,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 18),
            tooltip: 'Back',
            onPressed: () async {
              if (await _controller.canGoBack()) _controller.goBack();
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 18),
            tooltip: 'Forward',
            onPressed: () async {
              if (await _controller.canGoForward()) _controller.goForward();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Reload',
            onPressed: () => _controller.reload(),
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    GraceWayColor.golden.withValues(alpha: 0.7),
                  ),
                  minHeight: 2,
                ),
              )
            : null,
      ),
      body: _hasError ? _buildOfflinePlaceholder() : WebViewWidget(controller: _controller),
    );
  }
}
