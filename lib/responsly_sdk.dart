/// Responsly surveys inside Flutter apps on iOS and Android.
///
/// ```dart
/// await Responsly.initialize('rsk_…');
/// Responsly.identify('user-123', traits: {'plan': 'pro'});
/// Responsly.track('purchase_completed', properties: {'value': 49.9});
/// ```
///
/// Documentation: <https://developers.responsly.com/mobile-sdk/>
library;

export 'src/events.dart';
export 'src/navigator_observer.dart';
export 'src/options.dart';
export 'src/responsly.dart' show Responsly, ResponslyDisplayGuard;
