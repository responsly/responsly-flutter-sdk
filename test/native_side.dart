import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/src/responsly.dart' show debugResetResponsly;

/// Stands in for the native half of the plugin: records what Dart sends over the channel and
/// sends what the native SDK would send.
class NativeSide {
  static const MethodChannel channel = MethodChannel('responsly_sdk');

  /// Every call Dart made, in order, including the `attach` handshake.
  final List<MethodCall> calls = [];

  /// The calls without the `attach` handshake.
  List<MethodCall> get apiCalls =>
      calls.where((call) => call.method != 'attach').toList();

  /// The arguments of the only call of [method].
  Object? argumentsOf(String method) =>
      calls.singleWhere((call) => call.method == method).arguments;

  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// Starts every test from the state of a freshly started app with the plugin registered.
  void install() {
    TestWidgetsFlutterBinding.ensureInitialized();
    debugResetResponsly();
    calls.clear();
    _messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  }

  /// An app without the native plugin, such as a widget test or an unsupported platform.
  void uninstall() {
    _messenger.setMockMethodCallHandler(channel, null);
  }

  /// Makes every call fail the way a native error would.
  void failEveryCall() {
    _messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      throw PlatformException(code: 'invalid_arguments', message: 'nope');
    });
  }

  /// A call from the native side to Dart: an event (`surveyShown`, …) or `displayGuard`.
  Future<void> send(String method, [Object? arguments]) async {
    await _messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
    // Let listeners and the display guard run.
    await pumpEventQueue();
  }
}
