import 'package:flutter/foundation.dart';

/// How much the SDK logs. The lines come from the native SDK: read them in the Xcode console
/// or in Logcat.
enum ResponslyLogLevel {
  /// Nothing.
  none,

  /// Problems only. The default.
  error,

  /// Problems and the main steps, such as configuration downloads.
  info,

  /// Everything, including every targeting decision with its reason.
  debug,
}

/// The container a survey is presented in.
enum ResponslyPresentation {
  /// Attached to the bottom of the screen.
  bottomSheet,

  /// A centred card.
  dialog,

  /// Covers the whole screen.
  fullscreen,
}

/// Options for `Responsly.initialize`.
@immutable
class ResponslyOptions {
  const ResponslyOptions({
    this.apiHost = defaultApiHost,
    this.logLevel = ResponslyLogLevel.error,
  });

  /// `https://api.responsly.com`
  static const String defaultApiHost = 'https://api.responsly.com';

  /// Base address of the Responsly API. Leave it unset unless Responsly support gives you
  /// another host.
  final String apiHost;

  /// How much the SDK logs.
  final ResponslyLogLevel logLevel;

  @override
  bool operator ==(Object other) =>
      other is ResponslyOptions &&
      other.apiHost == apiHost &&
      other.logLevel == logLevel;

  @override
  int get hashCode => Object.hash(apiHost, logLevel);

  @override
  String toString() =>
      'ResponslyOptions(apiHost: $apiHost, logLevel: ${logLevel.name})';
}
