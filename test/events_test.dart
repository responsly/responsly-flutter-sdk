import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

import 'native_side.dart';

void main() {
  final native = NativeSide();
  late List<ResponslyEvent> received;

  setUp(() {
    native.install();
    received = [];
    final subscription = Responsly.events.listen(received.add);
    addTearDown(subscription.cancel);
  });

  group('surveyShown', () {
    test('carries the survey and the trigger', () async {
      await native.send('surveyShown', {
        'survey': {'id': 'AbCd1234', 'name': 'NPS after purchase'},
        'trigger': {'type': 'event', 'name': 'purchase_completed'},
      });

      final event = received.single as SurveyShown;
      expect(event.survey.id, 'AbCd1234');
      expect(event.survey.name, 'NPS after purchase');
      expect(event.trigger.type, 'event');
      expect(event.trigger.name, 'purchase_completed');
    });

    test('has no trigger name when the key is missing, as iOS sends it',
        () async {
      await native.send('surveyShown', {
        'survey': {'id': 'AbCd1234', 'name': 'NPS'},
        'trigger': {'type': 'manual'},
      });

      final event = received.single as SurveyShown;
      expect(event.trigger.type, 'manual');
      expect(event.trigger.name, isNull);
    });

    test('has no trigger name when it is null, as Android sends it', () async {
      await native.send('surveyShown', {
        'survey': {'id': 'AbCd1234', 'name': 'NPS'},
        'trigger': {'type': 'app_launch', 'name': null},
      });

      final event = received.single as SurveyShown;
      expect(event.trigger.type, 'app_launch');
      expect(event.trigger.name, isNull);
    });
  });

  test('surveyNotShown carries the reason as the protocol string', () async {
    await native.send('surveyNotShown',
        {'survey_id': 'AbCd1234', 'reason': 'frequency_limit'});

    final event = received.single as SurveyNotShown;
    expect(event.surveyId, 'AbCd1234');
    expect(event.reason, 'frequency_limit');
  });

  group('questionAnswered', () {
    Future<QuestionAnswered> answered(Object? value) async {
      await native.send('questionAnswered', {
        'survey_id': 'AbCd1234',
        'question_id': 'q1',
        'type': 'nps',
        'title': 'How likely are you to recommend us?',
        'value': value,
      });
      return received.last as QuestionAnswered;
    }

    test('carries the question and the answer', () async {
      final event = await answered(9);

      expect(event.surveyId, 'AbCd1234');
      expect(event.questionId, 'q1');
      expect(event.type, 'nps');
      expect(event.title, 'How likely are you to recommend us?');
      expect(event.value, 9);
    });

    test('the value is a plain Dart value of any JSON type', () async {
      expect((await answered('Great')).value, 'Great');
      expect((await answered(9)).value, isA<int>());
      expect((await answered(4.5)).value, 4.5);
      expect((await answered(true)).value, isTrue);
      expect((await answered(null)).value, isNull);
      expect((await answered(['a', 'b'])).value, ['a', 'b']);
    });

    test('lists and maps are typed like decoded JSON, at every depth',
        () async {
      final event = await answered({
        'choice': 'other',
        'details': {
          'text': 'Something else',
          'tags': [
            {'id': 1}
          ],
        },
      });

      final value = event.value;
      expect(value, isA<Map<String, Object?>>());
      value as Map<String, Object?>;
      expect(value['details'], isA<Map<String, Object?>>());
      final details = value['details'] as Map<String, Object?>;
      expect(details['tags'], isA<List<Object?>>());
      expect((details['tags'] as List<Object?>).single,
          isA<Map<String, Object?>>());
      expect(value, {
        'choice': 'other',
        'details': {
          'text': 'Something else',
          'tags': [
            {'id': 1}
          ],
        },
      });
    });
  });

  group('surveyCompleted', () {
    test('carries the response ID and the answers', () async {
      await native.send('surveyCompleted', {
        'survey_id': 'AbCd1234',
        'response_id': 'resp_1',
        'answers': [
          {
            'question_id': 'q1',
            'type': 'nps',
            'title': 'How likely are you to recommend us?',
            'value': 10,
          },
          {
            'question_id': 'q2',
            'type': 'multiple_choice',
            'title': 'What do you use?',
            'value': ['web', 'mobile'],
          },
          {
            'question_id': 'q3',
            'type': 'text',
            'title': 'Anything else?',
            'value': null,
          },
        ],
      });

      final event = received.single as SurveyCompleted;
      expect(event.surveyId, 'AbCd1234');
      expect(event.responseId, 'resp_1');
      expect(event.answers, hasLength(3));
      expect(event.answers[0].questionId, 'q1');
      expect(event.answers[0].type, 'nps');
      expect(event.answers[0].title, 'How likely are you to recommend us?');
      expect(event.answers[0].value, 10);
      expect(event.answers[1].value, ['web', 'mobile']);
      expect(event.answers[2].value, isNull);
    });

    test('the NPS recipe of the documentation finds the score', () async {
      await native.send('surveyCompleted', {
        'survey_id': 'AbCd1234',
        'response_id': 'resp_1',
        'answers': [
          {'question_id': 'q0', 'type': 'text', 'title': 'Why?', 'value': 'x'},
          {'question_id': 'q1', 'type': 'nps', 'title': 'NPS', 'value': 9},
        ],
      });

      final SurveyCompleted(:answers) = received.single as SurveyCompleted;
      final score = answers
          .where((answer) => answer.type == 'nps')
          .map((answer) => answer.value)
          .whereType<num>()
          .firstOrNull;
      expect(score, 9);
    });

    test('has an empty list without answers', () async {
      await native.send('surveyCompleted',
          {'survey_id': 'AbCd1234', 'response_id': 'resp_1'});

      expect((received.single as SurveyCompleted).answers, isEmpty);
    });
  });

  test('surveyDismissed carries the Survey ID', () async {
    await native.send('surveyDismissed', {'survey_id': 'AbCd1234'});

    expect((received.single as SurveyDismissed).surveyId, 'AbCd1234');
  });

  test('surveyError carries the code and the message', () async {
    await native.send('surveyError', {
      'survey_id': 'AbCd1234',
      'code': 'submit_failed',
      'message': 'The response could not be saved',
    });

    final event = received.single as SurveyError;
    expect(event.surveyId, 'AbCd1234');
    expect(event.code, 'submit_failed');
    expect(event.message, 'The response could not be saved');
  });

  test('a switch over an event covers the six types', () async {
    String describe(ResponslyEvent event) => switch (event) {
          SurveyShown(:final survey, :final trigger) =>
            'shown ${survey.id} ${trigger.type}',
          SurveyNotShown(:final surveyId, :final reason) =>
            'not shown $surveyId $reason',
          QuestionAnswered(
            :final surveyId,
            :final questionId,
            :final type,
            :final title,
            :final value
          ) =>
            'answered $surveyId $questionId $type $title $value',
          SurveyCompleted(:final surveyId, :final responseId, :final answers) =>
            'completed $surveyId $responseId ${answers.length}',
          SurveyDismissed(:final surveyId) => 'dismissed $surveyId',
          SurveyError(:final surveyId, :final code, :final message) =>
            'error $surveyId $code $message',
        };

    await native.send('surveyDismissed', {'survey_id': 'AbCd1234'});

    expect(describe(received.single), 'dismissed AbCd1234');
  });

  group('delivery', () {
    test('every listener gets every event', () async {
      final second = <ResponslyEvent>[];
      final subscription = Responsly.events.listen(second.add);
      addTearDown(subscription.cancel);

      await native.send('surveyDismissed', {'survey_id': 'a'});
      await native.send('surveyDismissed', {'survey_id': 'b'});

      expect(received, hasLength(2));
      expect(second, hasLength(2));
    });

    test('a cancelled listener gets nothing more', () async {
      final second = <ResponslyEvent>[];
      final subscription = Responsly.events.listen(second.add);
      await native.send('surveyDismissed', {'survey_id': 'a'});
      await subscription.cancel();
      await native.send('surveyDismissed', {'survey_id': 'b'});

      expect(second, hasLength(1));
      expect(received, hasLength(2));
    });

    test('calls that are not events are ignored', () async {
      await native.send('somethingNew', {'survey_id': 'AbCd1234'});

      expect(received, isEmpty);
    });

    test('an event without a usable payload is ignored', () async {
      await native.send('surveyDismissed');
      await native.send('surveyDismissed', 'AbCd1234');

      expect(received, isEmpty);
    });

    test('missing fields become empty strings instead of an error', () async {
      await native.send('surveyShown', <String, Object?>{});
      await native.send('surveyError', {'survey_id': 7});

      final shown = received[0] as SurveyShown;
      expect(shown.survey.id, '');
      expect(shown.survey.name, '');
      expect(shown.trigger.type, '');
      expect(shown.trigger.name, isNull);
      expect((received[1] as SurveyError).surveyId, '');
    });
  });
}
