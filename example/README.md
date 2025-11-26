# responsly_sdk example

A control panel for trying the plugin: enter an SDK key and an API host, press the buttons and
watch the events arrive in the log.

```bash
flutter run
```

| Control | Call |
|---|---|
| Initialize | `Responsly.initialize(key, options: ResponslyOptions(apiHost: host, logLevel: ResponslyLogLevel.debug))` |
| Identify demo user | `Responsly.identify('demo-user', traits: {...})` |
| Track purchase_completed | `Responsly.track('purchase_completed', properties: {'value': 49.9})` |
| Screen Checkout | `Responsly.screen('Checkout')` |
| Show survey, Force | `Responsly.showSurvey(id, force: ...)` |
| Pause / Resume / Close / Reset | `Responsly.pause()`, `resume()`, `closeSurvey()`, `reset()` |

The log shows every event of `Responsly.events`, newest first, and prints the same lines to the
console with the prefix `[ResponslyExample]`. The SDK's own debug log (`[Responsly]`) is in the
Xcode console or in Logcat.

The example allows plain HTTP (`NSAllowsArbitraryLoads` in `ios/Runner/Info.plist`,
`android:usesCleartextTraffic` in `android/app/src/main/AndroidManifest.xml`) so it can be
pointed at a backend on your own machine. Do not copy those two settings into your app.
