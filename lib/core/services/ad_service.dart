import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad Unit IDs. These are Google's official public **test** IDs — safe to
/// ship during development, but they only ever serve test creatives and
/// earn no real revenue. Swap these for the real IDs from your own AdMob
/// account (https://apps.admob.com) before a production release; the
/// AndroidManifest's `APPLICATION_ID` meta-data (see android/app/src/main/
/// AndroidManifest.xml) needs the same swap.
class AdUnitIds {
  const AdUnitIds._();

  static const banner = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitial = 'ca-app-pub-3940256099942544/1033173712';
}

/// Thin wrapper around the Mobile Ads SDK: one-time init, plus an
/// interstitial preloader so `showAfterMockTest()` never blocks on a
/// network round-trip at the moment a student finishes a test.
class AdService {
  AdService._();

  static bool _initialized = false;
  static InterstitialAd? _interstitial;

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

  /// Shows a preloaded interstitial if one's ready; silently does nothing
  /// otherwise (e.g. no network, or still loading) — a missing ad should
  /// never block a student from seeing their mock test result.
  static void showAfterMockTest() {
    _interstitial?.show();
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
