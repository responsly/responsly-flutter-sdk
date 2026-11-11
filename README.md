# Responsly Flutter SDK

Show [Responsly](https://responsly.com) surveys inside your Flutter app. You choose in Responsly who should see a survey and when; the SDK downloads that configuration, decides on the device and presents the survey as a bottom sheet, a dialog or full screen.

- iOS and Android, one Dart API
- Targeting runs on the device: events, screens, app launch, user traits, sampling, frequency and schedule
- What happens to a survey arrives as a Dart stream of typed events
- No advertising identifier, no fingerprinting, no location; ships a privacy manifest on iOS

Full documentation: **https://developers.responsly.com/mobile-sdk/**

## Requirements

- Flutter 3.24 or later, Dart 3.5 or later
- iOS 15 or later, Android `minSdk` 23 or higher
- The team's SDK key (`rsk_…`) from the form's **Share → Mobile app** tab

## Install

```bash
flutter pub add responsly_sdk
```

Or add it by hand and run `flutter pub get`:

```yaml
dependencies:
  responsly_sdk: ^1.2.2
```

The plugin contains the native Responsly SDKs for iOS and Android as source, so there is nothing else to add: no pod, no Maven repository, no manifest entry. On iOS it works with both Swift Package Manager and CocoaPods.

Raise the platform minimums if your project is below them:

```ruby
# ios/Podfile
platform :ios, '15.0'
```

```kotlin
// android/app/build.gradle.kts
android {
    defaultConfig {
        minSdk = 23
    }
}
```

## Quick start

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Start the SDK once, before runApp.
  await Responsly.initialize(
    'rsk_…',
    options: const ResponslyOptions(
      logLevel: kDebugMode ? ResponslyLogLevel.debug : ResponslyLogLevel.error,
    ),
  );

  runApp(const MyApp());
}
```

```dart
// 2. Tell it who the user is. Traits are used for targeting and passed to the survey.
Responsly.identify('user-123', traits: {
  'plan': 'pro',
  'seats': 5,
  'beta': true,
  'signed_up': DateTime.now(),
});

// 3. Report what happens in the app. Surveys with a matching trigger show by themselves.
Responsly.track('purchase_completed', properties: {'value': 49.9});
Responsly.screen('Checkout');

// Or show a survey yourself.
Responsly.showSurvey('AbCd1234');

// 4. Listen to what happens.
final subscription = Responsly.events.listen((event) {
  switch (event) {
    case SurveyCompleted(:final responseId, :final answers):
      debugPrint('completed $responseId, ${answers.length} answers');
    case SurveyNotShown(:final surveyId, :final reason):
      debugPrint('not shown $surveyId: $reason');
    default:
      break;
  }
});

// 5. On logout.
Responsly.reset();
```

Every method returns `Future<void>`. You do not have to await it: calls are applied in the order you make them, they never complete with an error, and calls made before `initialize` are remembered and applied when the SDK starts.

## API

All calls are static methods of `Responsly`.

| Call | What it does |
|---|---|
| `initialize(sdkKey, {options})` | Starts the SDK. `ResponslyOptions(apiHost, logLevel)`. Idempotent for the same key; a different key resets the local state first. |
| `identify(userId, {traits})` | Sets the user ID and merges the traits into the stored ones. |
| `setAttributes(traits)` | Merges traits without changing the user ID. A `null` value removes a trait. |
| `track(event, {properties})` | Adds one to the event's count and evaluates event triggers. |
| `screen(name)` | Sets the current screen and evaluates screen triggers. |
| `showSurvey(surveyId, {force, hiddenFields, locale, presentation})` | Shows a survey by its Survey ID. Audience, schedule and frequency apply unless `force` is set. |
| `closeSurvey()` | Closes the survey that is visible or waiting to appear. |
| `pause()` / `resume()` | Stops and resumes surveys started by triggers. `showSurvey` still works while paused. |
| `setLocale(tag)` | Overrides the language for surveys and for the languages audience rule. `null` returns to the device language. |
| `setHiddenFields(fields)` | Hidden-field values sent with every survey. Replaces the previous map. |
| `setTrackingEnabled(enabled)` | `false` switches the SDK off: no network, no targeting, nothing shown. Saved on the device. |
| `reset()` | Forgets the user and all local state except the install ID and the tracking setting. Call it on logout. |
| `setDisplayGuard(guard)` | Sets a function that can veto a survey right before it appears. `null` removes it. |
| `events` | A broadcast `Stream<ResponslyEvent>`. |

Trait and property values are a `String`, an `int` or `double`, a `bool` or a `DateTime`. Dates are stored and compared in UTC with seconds precision, as `2026-11-10T12:00:00Z`.

Types: `ResponslyOptions`, `ResponslyLogLevel` (`none`, `error`, `info`, `debug`), `ResponslyPresentation` (`bottomSheet`, `dialog`, `fullscreen`), `ResponslySurvey` (`id`, `name`), `ResponslyTrigger` (`type`, `name`), `ResponslyAnswer` (`questionId`, `type`, `title`, `value`).

### Events

`ResponslyEvent` is a sealed class, so a `switch` over an event is checked for completeness.

| Event | Fires when | Fields |
|---|---|---|
| `SurveyShown` | The survey became visible. | `survey` (`id`, `name`), `trigger` (`type`, `name`) |
| `SurveyNotShown` | A survey matched a trigger or was requested with `showSurvey`, but was not shown. | `surveyId`, `reason` |
| `QuestionAnswered` | The respondent answered a question. | `surveyId`, `questionId`, `type`, `title`, `value` |
| `SurveyCompleted` | The respondent submitted the survey. | `surveyId`, `responseId`, `answers` |
| `SurveyDismissed` | The survey was closed before it was completed. | `surveyId` |
| `SurveyError` | The survey reported an error while it was visible. | `surveyId`, `code`, `message` |

`reason` is one of the [not-shown reasons](https://developers.responsly.com/mobile-sdk/testing/#not-shown-reasons), for example `frequency_limit` or `audience_mismatch`. `trigger.type` is `event`, `screen`, `app_launch` or `manual`; `trigger.name` is `null` for the last two. An answer's `value` is a plain Dart value: a `String`, a `num`, a `bool`, a `List<Object?>` or a `Map<String, Object?>`.

Events are delivered as they happen. One that fired while nobody was listening is not repeated to a later listener.

### Display guard

```dart
Responsly.setDisplayGuard((survey) async => !checkoutInProgress);
```

The guard is asked right before a survey would appear, with the survey's `id` and `name`. Complete with `false` to veto it; the survey is then reported as `SurveyNotShown` with the reason `vetoed`. No answer within 2 seconds counts as allow, and so does a guard that throws. It is not asked for `showSurvey(…, force: true)`.

### Navigator observer

`ResponslyNavigatorObserver` reports named routes as screens, so screen triggers work without calling `screen` by hand:

```dart
MaterialApp(
  navigatorObservers: [ResponslyNavigatorObserver()],
  routes: {
    '/': (context) => const HomePage(),
    '/checkout': (context) => const CheckoutPage(),
  },
);
```

It calls `Responsly.screen` with the route's `settings.name` on push, pop and replace. Routes without a name are skipped; name the ones you push by hand with `RouteSettings(name: 'Checkout')`.

## Debugging

```dart
await Responsly.initialize('rsk_…', options: const ResponslyOptions(logLevel: ResponslyLogLevel.debug));
```

With the `debug` level the SDK logs every targeting decision with its reason. The lines come from the native SDK and are prefixed `[Responsly]`: read them in the Xcode console or in Logcat, not in the Dart console. To see a survey regardless of targeting, call `Responsly.showSurvey('AbCd1234', force: true)`.

In widget tests and on platforms other than iOS and Android, every call does nothing.

## Example app

[`example/`](example) is a control panel: enter an SDK key and an API host, press the buttons and watch the events arrive.

```bash
cd example
flutter run
```

## How the package is built

The Dart API is a thin layer over the native Responsly SDKs. Their sources are stored in this repository and compiled with the plugin:

| | Native SDK sources | Plugin code |
|---|---|---|
| iOS | `ios/responsly_sdk/Sources/responsly_sdk/ResponslySDK/` | `ios/responsly_sdk/Sources/responsly_sdk/ResponslySdkPlugin.swift` |
| Android | `android/src/main/kotlin/com/responsly/sdk/`, `android/src/main/AndroidManifest.xml`, `android/consumer-rules.pro` | `android/src/main/kotlin/com/responsly/flutter/ResponslySdkPlugin.kt` |

Do not edit the native sources here. `tool/sync_native.sh` copies them from the [iOS](https://github.com/responsly/responsly-ios-sdk) and [Android](https://github.com/responsly/responsly-android-sdk) repositories and writes the commits it copied to `native-sdk.lock`:

```bash
tool/sync_native.sh                 # expects ../responsly-ios-sdk and ../responsly-android-sdk
tool/sync_native.sh --ios <dir> --android <dir>
```

On iOS the same files are built by `ios/responsly_sdk.podspec` (CocoaPods) and by `ios/responsly_sdk/Package.swift` (Swift Package Manager). The Android module needs `androidx.webkit` and `androidx.annotation` at the versions the Android SDK pins; `android/build.gradle` reads them from `native-sdk.lock`.

## Development

```bash
flutter analyze
flutter test
cd example && flutter build apk --debug
cd example && flutter build ios --simulator --debug
dart pub publish --dry-run
```

The example app builds the plugin with CocoaPods (`flutter: config: enable-swift-package-manager: false` in `example/pubspec.yaml`). To build it with Swift Package Manager, the repository directory has to be named like the package, because Flutter refers to the plugin of an example app by its directory name:

```bash
git clone https://github.com/responsly/responsly-flutter-sdk responsly_sdk
cd responsly_sdk/example
# set enable-swift-package-manager to true in pubspec.yaml, then
flutter build ios --simulator --debug
```

Apps that use the published package are not affected: they get the plugin through whichever of the two their Flutter version uses.

## License

[MIT](LICENSE)
