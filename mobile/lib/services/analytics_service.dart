import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'log_service.dart';

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._internal();
  factory AnalyticsService() => instance;
  AnalyticsService._internal();

  bool _initialized = false;

  /// Initialize PostHog with compile-time env vars.
  /// Pass POSTHOG_KEY and POSTHOG_HOST via --dart-define at build time.
  /// Returns true if PostHog was enabled, false if skipped.
  Future<bool> initialize() async {
    const apiKey = String.fromEnvironment('POSTHOG_KEY');
    const host = String.fromEnvironment(
      'POSTHOG_HOST',
      defaultValue: 'https://us.i.posthog.com',
    );

    if (apiKey.isEmpty) {
      LogService.instance.info('Analytics', 'PostHog disabled (no POSTHOG_KEY)');
      return false;
    }

    // Skip on Flutter web — the Rails app already includes PostHog JS
    if (kIsWeb) {
      LogService.instance.info('Analytics', 'PostHog skipped on web (handled by Rails)');
      return false;
    }

    try {
      final config = PostHogConfig(apiKey);
      config.host = host;
      config.debug = kDebugMode;
      config.captureApplicationLifecycleEvents = true;
      config.sessionReplay = true;
      config.sessionReplayConfig.maskAllTexts = false;
      config.sessionReplayConfig.maskAllImages = false;
      config.sessionReplayConfig.screenshot = true;

      await Posthog().setup(config);
      _initialized = true;
      LogService.instance.info('Analytics', 'PostHog initialized (host: $host)');
      return true;
    } catch (e, stackTrace) {
      LogService.instance.error('Analytics', 'PostHog init failed: $e\n$stackTrace');
      return false;
    }
  }

  /// Identify a user after login.
  void identify({required String userId, required String email, String? name}) {
    if (!_initialized) return;
    try {
      Posthog().identify(
        userId: userId,
        userProperties: {
          'email': email,
          if (name != null) 'name': name,
        },
      );
      LogService.instance.debug('Analytics', 'Identified user: $userId');
    } catch (e) {
      LogService.instance.error('Analytics', 'Identify failed: $e');
    }
  }

  /// Reset identity on logout.
  void reset() {
    if (!_initialized) return;
    try {
      Posthog().reset();
      LogService.instance.debug('Analytics', 'PostHog reset');
    } catch (e) {
      LogService.instance.error('Analytics', 'Reset failed: $e');
    }
  }

  /// Capture a custom event.
  void capture(String event, [Map<String, Object>? properties]) {
    if (!_initialized) return;
    try {
      Posthog().capture(eventName: event, properties: properties);
    } catch (e) {
      LogService.instance.error('Analytics', 'Capture failed: $e');
    }
  }
}
