import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

import 'native_side.dart';

void main() {
  final native = NativeSide();
  setUp(native.install);

  test('an event before the first listener does not fail and is not replayed',
      () async {
    // Dart attached (a call was made), but nobody listens to Responsly.events yet.
    await Responsly.initialize('rsk_test');
    await native.send('surveyNotShown',
        {'survey_id': 'AbCd1234', 'reason': 'config_unavailable'});

    final received = <ResponslyEvent>[];
    final subscription = Responsly.events.listen(received.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();
    expect(received, isEmpty);

    await native.send('surveyDismissed', {'survey_id': 'AbCd1234'});
    expect(received.single, isA<SurveyDismissed>());
  });

  test('an event before Dart made any call does not fail', () async {
    await native.send('surveyDismissed', {'survey_id': 'AbCd1234'});

    final received = <ResponslyEvent>[];
    final subscription = Responsly.events.listen(received.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    expect(received, isEmpty);
  });
}
