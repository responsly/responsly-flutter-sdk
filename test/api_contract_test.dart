// The Flutter block of the SDK's API specification, as an app would write it. It has to
// compile exactly like this, and every line has to reach the native side.

import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

import 'native_side.dart';

void main() {
  final native = NativeSide();
  setUp(native.install);

  test('the documented API compiles and forwards every call', () async {
    const checkoutInProgress = false;

    await Responsly.initialize('rsk_…',
        options: const ResponslyOptions(
            apiHost: 'https://api.responsly.com',
            logLevel: ResponslyLogLevel.debug));
    Responsly.identify('user-123', traits: {
      'plan': 'pro',
      'seats': 5,
      'beta': true,
      'signed_up': DateTime.now()
    });
    Responsly.setAttributes({'plan': 'team', 'beta': null});
    Responsly.track('purchase_completed', properties: {'value': 49.9});
    Responsly.screen('Checkout');
    Responsly.showSurvey('AbCd1234',
        force: false,
        hiddenFields: {'order_id': 'A-77'},
        locale: 'pl',
        presentation: ResponslyPresentation.dialog);
    Responsly.closeSurvey();
    Responsly.pause();
    Responsly.resume();
    Responsly.setLocale('pl'); // null = device language
    Responsly.setHiddenFields({'order_id': 'A-77'});
    Responsly.setTrackingEnabled(false);
    Responsly.reset();
    Responsly.setDisplayGuard(
        (survey) async => !checkoutInProgress); // null removes
    final subscription = Responsly.events.listen((event) {
      switch (event) {
        case SurveyShown(:final survey, :final trigger):
          expect(
              [survey.id, survey.name, trigger.type, trigger.name], isNotNull);
          break;
        case SurveyNotShown(:final surveyId, :final reason):
          expect([surveyId, reason], isNotNull);
          break;
        case QuestionAnswered(
            :final surveyId,
            :final questionId,
            :final type,
            :final title,
            :final value
          ):
          expect([surveyId, questionId, type, title, value], isNotNull);
          break;
        case SurveyCompleted(
            :final surveyId,
            :final responseId,
            :final answers
          ):
          expect([surveyId, responseId, answers], isNotNull);
          break;
        case SurveyDismissed(:final surveyId):
          expect(surveyId, isNotNull);
          break;
        case SurveyError(:final surveyId, :final code, :final message):
          expect([surveyId, code, message], isNotNull);
          break;
      }
    });
    await pumpEventQueue();
    await subscription.cancel();

    expect(native.calls.map((call) => call.method), [
      'attach',
      'initialize',
      'identify',
      'setAttributes',
      'track',
      'screen',
      'showSurvey',
      'closeSurvey',
      'pause',
      'resume',
      'setLocale',
      'setHiddenFields',
      'setTrackingEnabled',
      'reset',
      'setDisplayGuard',
    ]);
  });

  test('every call returns a Future<void>', () {
    final futures = <Future<void>>[
      Responsly.initialize('rsk_…'),
      Responsly.identify('user-123'),
      Responsly.setAttributes(const {}),
      Responsly.track('purchase_completed'),
      Responsly.screen('Checkout'),
      Responsly.showSurvey('AbCd1234'),
      Responsly.closeSurvey(),
      Responsly.pause(),
      Responsly.resume(),
      Responsly.setLocale(null),
      Responsly.setHiddenFields(const {}),
      Responsly.setTrackingEnabled(true),
      Responsly.reset(),
      Responsly.setDisplayGuard(null),
    ];

    expect(Future.wait(futures), completes);
  });

  test('events is a broadcast stream', () {
    expect(Responsly.events.isBroadcast, isTrue);
  });
}
