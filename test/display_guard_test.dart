import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

import 'native_side.dart';

void main() {
  final native = NativeSide();
  setUp(native.install);

  Future<void> ask(int requestId, {String id = 'AbCd1234'}) {
    return native.send('displayGuard', {
      'request_id': requestId,
      'survey': {'id': id, 'name': 'NPS after purchase'},
    });
  }

  test('a guard that completes with true allows the survey', () async {
    await Responsly.setDisplayGuard((survey) async => true);
    await ask(1);

    expect(native.argumentsOf('resolveDisplayGuard'),
        {'request_id': 1, 'allow': true});
  });

  test('a guard that completes with false vetoes the survey', () async {
    await Responsly.setDisplayGuard((survey) async => false);
    await ask(2);

    expect(native.argumentsOf('resolveDisplayGuard'),
        {'request_id': 2, 'allow': false});
  });

  test('a guard that throws allows the survey', () async {
    await Responsly.setDisplayGuard(
        (survey) async => throw StateError('broken guard'));
    await ask(3);

    expect(native.argumentsOf('resolveDisplayGuard'),
        {'request_id': 3, 'allow': true});
  });

  test('a guard that throws before returning a future allows the survey',
      () async {
    await Responsly.setDisplayGuard((survey) => throw StateError('broken'));
    await ask(4);

    expect(native.argumentsOf('resolveDisplayGuard'),
        {'request_id': 4, 'allow': true});
  });

  test('the guard gets the survey and can decide per survey', () async {
    final asked = <ResponslySurvey>[];
    await Responsly.setDisplayGuard((survey) async {
      asked.add(survey);
      return survey.id == 'AbCd1234';
    });
    await ask(5, id: 'AbCd1234');
    await ask(6, id: 'ZyXw9876');

    expect(asked.map((survey) => survey.id), ['AbCd1234', 'ZyXw9876']);
    expect(asked.first.name, 'NPS after purchase');
    expect(
      native.calls
          .where((call) => call.method == 'resolveDisplayGuard')
          .map((call) => call.arguments),
      [
        {'request_id': 5, 'allow': true},
        {'request_id': 6, 'allow': false},
      ],
    );
  });

  test('the answer is sent when the guard completes, not before', () async {
    final decision = Completer<bool>();
    await Responsly.setDisplayGuard((survey) => decision.future);
    await ask(7);

    expect(native.calls.where((call) => call.method == 'resolveDisplayGuard'),
        isEmpty);

    decision.complete(false);
    await pumpEventQueue();

    expect(native.argumentsOf('resolveDisplayGuard'),
        {'request_id': 7, 'allow': false});
  });

  test('a new guard replaces the old one', () async {
    await Responsly.setDisplayGuard((survey) async => false);
    await Responsly.setDisplayGuard((survey) async => true);
    await ask(8);

    expect(native.argumentsOf('resolveDisplayGuard'),
        {'request_id': 8, 'allow': true});
  });

  test('a question that arrives after the guard was removed is allowed',
      () async {
    await Responsly.setDisplayGuard((survey) async => false);
    await Responsly.setDisplayGuard(null);
    await ask(9);

    expect(native.argumentsOf('resolveDisplayGuard'),
        {'request_id': 9, 'allow': true});
  });

  test('a question without a request ID is ignored', () async {
    await Responsly.setDisplayGuard((survey) async => false);
    await native.send('displayGuard', {
      'survey': {'id': 'AbCd1234', 'name': 'NPS'},
    });
    await native.send('displayGuard');

    expect(native.calls.where((call) => call.method == 'resolveDisplayGuard'),
        isEmpty);
  });

  test('a guard question is not an event', () async {
    final received = <ResponslyEvent>[];
    final subscription = Responsly.events.listen(received.add);
    addTearDown(subscription.cancel);
    await Responsly.setDisplayGuard((survey) async => true);
    await ask(10);

    expect(received, isEmpty);
  });
}
