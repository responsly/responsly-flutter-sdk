import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'codec.dart';
import 'events.dart';
import 'options.dart';

/// Asked before a survey becomes visible. Complete with `false` to veto it.
///
/// See [Responsly.setDisplayGuard].
typedef ResponslyDisplayGuard = Future<bool> Function(ResponslySurvey survey);

/// The entry point of the Responsly SDK: in-app surveys, targeted on the device.
///
/// ```dart
/// await Responsly.initialize('rsk_…');
/// Responsly.identify('user-123', traits: {'plan': 'pro'});
/// Responsly.track('purchase_completed', properties: {'value': 49.9});
/// ```
///
/// Every method is fire-and-forget. It returns a `Future<void>` that completes when the call
/// has reached the native SDK; you do not have to await it, and it never completes with an
/// error. Calls are applied in the order you make them, and calls made before [initialize] are
/// remembered and applied when the SDK starts. What happens to a survey is reported through
/// [events].
///
/// The plugin forwards to the native Responsly SDKs for iOS and Android. On other platforms,
/// and in tests without the plugin, every call does nothing.
abstract final class Responsly {
  static const MethodChannel _channel = MethodChannel('responsly_sdk');

  static final StreamController<ResponslyEvent> _events =
      StreamController<ResponslyEvent>.broadcast();

  static ResponslyDisplayGuard? _displayGuard;
  static bool _attached = false;
  static bool _missingPluginReported = false;

  /// Starts the SDK: loads the cached configuration, downloads a new one when needed and
  /// applies the calls made so far. Call it in `main`, before `runApp`.
  ///
  /// Idempotent for the same key. A different key resets the SDK's local state first.
  ///
  /// [sdkKey] is the team's SDK key (`rsk_…`) from the form's **Share → Mobile app** tab.
  static Future<void> initialize(
    String sdkKey, {
    ResponslyOptions options = const ResponslyOptions(),
  }) {
    return _invoke('initialize', {
      'sdk_key': sdkKey,
      'api_host': options.apiHost,
      'log_level': options.logLevel.name,
    });
  }

  /// Sets the user ID and merges [traits] into the stored ones.
  ///
  /// Trait values are a `String`, an `int` or `double`, a `bool` or a [DateTime]. A `null`
  /// value removes the trait. Any other object is stored as its `toString()`.
  static Future<void> identify(
    String userId, {
    Map<String, Object?> traits = const {},
  }) {
    return _invoke('identify', {
      'user_id': userId,
      'traits': encodeValues(traits),
    });
  }

  /// Merges [traits] without changing the user ID. A `null` value removes a trait.
  static Future<void> setAttributes(Map<String, Object?> traits) {
    return _invoke('setAttributes', {'traits': encodeValues(traits)});
  }

  /// Adds one to the event's count and evaluates event triggers.
  ///
  /// Property values are a `String`, an `int` or `double`, a `bool` or a [DateTime].
  static Future<void> track(
    String event, {
    Map<String, Object?> properties = const {},
  }) {
    return _invoke('track', {
      'event': event,
      'properties': encodeValues(properties),
    });
  }

  /// Sets the current screen and evaluates screen triggers.
  ///
  /// `ResponslyNavigatorObserver` calls this for named routes.
  static Future<void> screen(String name) {
    return _invoke('screen', {'name': name});
  }

  /// Shows a survey by its Survey ID. The outcome arrives on [events]: [SurveyShown], or
  /// [SurveyNotShown] with the reason.
  ///
  /// Audience, schedule and frequency apply unless [force] is set, which also skips the
  /// display guard. [hiddenFields] and [locale] are for this survey only; a hidden field given
  /// here wins over the same key of [setHiddenFields]. [presentation] overrides the style set
  /// in the **Mobile app** tab.
  static Future<void> showSurvey(
    String surveyId, {
    bool force = false,
    Map<String, String> hiddenFields = const {},
    String? locale,
    ResponslyPresentation? presentation,
  }) {
    return _invoke('showSurvey', {
      'survey_id': surveyId,
      'force': force,
      'hidden_fields': Map<String, String>.of(hiddenFields),
      'locale': locale,
      'presentation':
          presentation == null ? null : encodePresentation(presentation),
    });
  }

  /// Closes the survey that is visible or waiting to appear. A visible survey that is not
  /// completed counts as dismissed. One that was still waiting or loading is cancelled without
  /// an event, because it was never shown.
  static Future<void> closeSurvey() => _invoke('closeSurvey');

  /// Stops surveys started by triggers until [resume]. [showSurvey] still works. Kept in
  /// memory only.
  static Future<void> pause() => _invoke('pause');

  /// Resumes surveys started by triggers after [pause].
  static Future<void> resume() => _invoke('resume');

  /// Overrides the language for surveys and for the languages audience rule, for example `pl`
  /// or `pt-BR`. `null` returns to the device language.
  static Future<void> setLocale(String? locale) {
    return _invoke('setLocale', {'locale': locale});
  }

  /// Sets the hidden-field values sent with every survey. Replaces the previous map.
  static Future<void> setHiddenFields(Map<String, String> fields) {
    return _invoke('setHiddenFields', {
      'fields': Map<String, String>.of(fields),
    });
  }

  /// `false` switches the SDK off: no network, no targeting, nothing shown. Saved on the device
  /// and kept by [reset].
  static Future<void> setTrackingEnabled(bool enabled) {
    return _invoke('setTrackingEnabled', {'enabled': enabled});
  }

  /// Forgets the user: clears the user ID, traits, language override, hidden fields, event
  /// counts, display history and cached configuration, and closes a visible survey. Call it on
  /// logout. The SDK stays initialized.
  static Future<void> reset() => _invoke('reset');

  /// Sets a function that is asked right before a survey would appear and can veto it by
  /// completing with `false`. `null` removes it.
  ///
  /// ```dart
  /// Responsly.setDisplayGuard((survey) async => !checkoutInProgress);
  /// ```
  ///
  /// No answer within 2 seconds counts as allow, and so does a guard that throws. A vetoed
  /// survey is reported as [SurveyNotShown] with the reason `vetoed`. The guard is not asked
  /// when [showSurvey] is called with `force`. There is one guard: setting a new one replaces
  /// the old one.
  static Future<void> setDisplayGuard(ResponslyDisplayGuard? guard) {
    _displayGuard = guard;
    return _invoke('setDisplayGuard', {'enabled': guard != null});
  }

  /// What happens to surveys, as a broadcast stream.
  ///
  /// ```dart
  /// final subscription = Responsly.events.listen((event) {
  ///   if (event case SurveyCompleted(:final responseId)) {
  ///     debugPrint('completed $responseId');
  ///   }
  /// });
  /// ```
  ///
  /// [ResponslyEvent] is a sealed class, so a `switch` over an event is checked for
  /// completeness. Events are delivered as they happen: one that fired while nobody was
  /// listening is not repeated to a later listener.
  static Stream<ResponslyEvent> get events {
    _attach();
    return _events.stream;
  }

  /// Tells the native side that Dart is ready for events and display-guard questions. Before
  /// this it sends nothing, so nothing arrives while there is no handler.
  static void _attach() {
    if (_attached) return;
    try {
      _channel.setMethodCallHandler(_onNativeCall);
    } catch (error) {
      // No binding yet: WidgetsFlutterBinding.ensureInitialized() was not called. The call
      // that follows reports it; try again on the next one.
      return;
    }
    _attached = true;
    _send('attach');
  }

  static Future<void> _invoke(String method,
      [Map<String, Object?>? arguments]) {
    _attach();
    return _send(method, arguments);
  }

  /// Sends one call. Never completes with an error: the API is fire-and-forget, and most
  /// callers do not await it.
  static Future<void> _send(String method,
      [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      if (!_missingPluginReported) {
        _missingPluginReported = true;
        _debugLog(
          'The native SDK is not available here (iOS and Android only); '
          'calls do nothing.',
        );
      }
    } catch (error) {
      _debugLog('$method failed: $error');
    }
  }

  static Future<Object?> _onNativeCall(MethodCall call) async {
    if (call.method == 'displayGuard') {
      unawaited(_answerDisplayGuard(call.arguments));
    } else if (_events.hasListener) {
      final event = decodeEvent(call.method, call.arguments);
      if (event != null) _events.add(event);
    }
    return null;
  }

  /// The native guard asks with a request ID; the answer goes back with the same ID.
  static Future<void> _answerDisplayGuard(Object? request) async {
    if (request is! Map) return;
    final requestId = request['request_id'];
    if (requestId is! int) return;

    var allow = true;
    final guard = _displayGuard;
    if (guard != null) {
      try {
        allow = await guard(decodeSurvey(request['survey']));
      } catch (error) {
        _debugLog('The display guard threw, so the survey is allowed: $error');
      }
    }
    await _send('resolveDisplayGuard', {
      'request_id': requestId,
      'allow': allow,
    });
  }

  static void _debugLog(String message) {
    assert(() {
      debugPrint('[Responsly] $message');
      return true;
    }());
  }
}

/// Returns the plugin to its state at app start. For this package's own tests; not exported
/// from `responsly_sdk.dart`.
@visibleForTesting
void debugResetResponsly() {
  Responsly._channel.setMethodCallHandler(null);
  Responsly._displayGuard = null;
  Responsly._attached = false;
  Responsly._missingPluginReported = false;
}
