import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad Unit IDs — from the real AdMob account
/// (admob.google.com, app "CTET & State TET Prep", app ID
/// ca-app-pub-4806343972940588~1328644052, see AndroidManifest's
/// `APPLICATION_ID` meta-data for that one).
class AdUnitIds {
  const AdUnitIds._();

  static const banner = 'ca-app-pub-4806343972940588/1563663954';
  static const interstitial = 'ca-app-pub-4806343972940588/9361378440';
}

/// Thin wrapper around the Mobile Ads SDK: one-time init, plus an
/// interstitial preloader so `showAfterMockTest()` never blocks on a
/// network round-trip at the moment a student finishes a test.
class AdService {
  AdService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitial;
  static DateTime? _lastInterstitialShownAt;

  /// Minimum gap between two interstitials, regardless of which trigger
  /// fired them — without this, a student who finishes a test (ad after
  /// the result) and immediately taps "View Syllabus" or a revision block
  /// (ad before opening) would see two full-screen ads back to back.
  static const _interstitialCooldown = Duration(seconds: 75);

  static bool get _cooledDown {
    final last = _lastInterstitialShownAt;
    return last == null || DateTime.now().difference(last) >= _interstitialCooldown;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _loadInterstitial();
  }

  static void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdUnitIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              _loadInterstitial(); // keep one ready for next time
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitial = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _interstitial = null;
        },
      ),
    );
  }

  /// Shows a preloaded interstitial if one's ready (and the cooldown has
  /// elapsed); silently does nothing otherwise (e.g. no network, still
  /// loading, or an ad was shown too recently) — a missing ad should never
  /// block a student from seeing their mock test result.
  static void showAfterMockTest() {
    final ad = _interstitial;
    if (ad == null || !_cooledDown) return;
    _lastInterstitialShownAt = DateTime.now();
    ad.show();
  }

  /// Gate before opening locked/gated content (a non-free test, a
  /// revision block, the syllabus, ...): shows a preloaded interstitial
  /// and calls [onFinished] once it's dismissed. Same fail-open stance as
  /// [showAfterMockTest] — no ad ready (no network, still loading, or —
  /// unless [ignoreCooldown] — the cooldown hasn't elapsed) means
  /// [onFinished] fires immediately rather than blocking the student from
  /// the content they tapped.
  ///
  /// [ignoreCooldown] is for a locked test/block someone deliberately
  /// tapped past the free first one — that's a paywall moment, not
  /// incidental browsing, so it always shows an ad if one's loaded,
  /// regardless of how recently the last one ran.
  static void showBeforeOpeningContent(
    VoidCallback onFinished, {
    bool ignoreCooldown = false,
  }) {
    final ad = _interstitial;
    if (ad == null || (!ignoreCooldown && !_cooledDown)) {
      onFinished();
      return;
    }
    _lastInterstitialShownAt = DateTime.now();
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        onFinished();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        onFinished();
      },
    );
    ad.show();
  }
}

/// Drop-in banner ad, sized to Google's standard adaptive banner. Used at
/// the bottom of the dashboard; each instance loads/disposes its own
/// `BannerAd` so it works wherever it's placed.
class AppBannerAd extends StatefulWidget {
  const AppBannerAd({super.key});

  @override
  State<AppBannerAd> createState() => _AppBannerAdState();
}

class _AppBannerAdState extends State<AppBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = BannerAd(
      adUnitId: AdUnitIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _isLoaded = true),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    ad.load();
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
