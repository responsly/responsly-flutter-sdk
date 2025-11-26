import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk_example/main.dart';

void main() {
  const channel = MethodChannel('responsly_sdk');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  testWidgets('Initialize sends the key, the host and the debug log level', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.tap(find.byKey(const Key('initialize')));
    await tester.pump();

    final initialize = calls.singleWhere((call) => call.method == 'initialize');
    expect(initialize.arguments, {
      'sdk_key': 'rsk_demo',
      'api_host': 'https://api.responsly.com',
      'log_level': 'debug',
    });
    expect(find.textContaining('initialize rsk_demo'), findsOneWidget);
  });

  testWidgets('events are written to the log', (tester) async {
    await tester.pumpWidget(const ExampleApp());

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('surveyNotShown', {
              'survey_id': 'AbCd1234',
              'reason': 'frequency_limit',
            }),
          ),
          (_) {},
        );
    await tester.pump();

    expect(
      find.textContaining('surveyNotShown AbCd1234 reason=frequency_limit'),
      findsOneWidget,
    );
  });
}
