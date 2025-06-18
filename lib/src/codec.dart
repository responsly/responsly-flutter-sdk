/// What crosses the platform channel, in both directions. Not part of the public API.
///
/// Every key is snake_case, like the `toMap()` / `toDictionary()` output of the native SDKs,
/// which is forwarded to Dart unchanged.
library;

import 'events.dart';
import 'options.dart';

/// Trait and property values as they are sent to the native SDK.
///
/// Strings, numbers and booleans go as they are, a [DateTime] as an ISO 8601 UTC string with
/// seconds precision, and `null` is kept (it removes a trait). The channel cannot carry other
/// objects, so anything else goes as its `toString()`.
Map<String, Object?> encodeValues(Map<String, Object?> values) => {
      for (final MapEntry(:key, :value) in values.entries)
        key: encodeValue(value),
    };

Object? encodeValue(Object? value) => switch (value) {
      null || String() || num() || bool() => value,
      DateTime() => encodeDate(value),
      _ => value.toString(),
    };

/// `2026-11-10T12:00:00Z`: UTC, seconds precision, the form the SDK stores and compares.
String encodeDate(DateTime date) {
  final utc = date.toUtc();
  String pad(int number, [int width = 2]) =>
      number.toString().padLeft(width, '0');
  return '${pad(utc.year, 4)}-${pad(utc.month)}-${pad(utc.day)}'
      'T${pad(utc.hour)}:${pad(utc.minute)}:${pad(utc.second)}Z';
}

/// The protocol name of a presentation style.
String encodePresentation(ResponslyPresentation presentation) =>
    switch (presentation) {
      ResponslyPresentation.bottomSheet => 'bottom_sheet',
      ResponslyPresentation.dialog => 'dialog',
      ResponslyPresentation.fullscreen => 'fullscreen',
    };

/// Decodes an event sent by the native side as the method [name] with the event's map as
/// [payload]. Returns `null` for anything that is not an event.
///
/// Decoding is lenient: a missing or mistyped text field becomes an empty string rather than
/// an exception, so a listener is never skipped because of one field.
ResponslyEvent? decodeEvent(String name, Object? payload) {
  if (payload is! Map) return null;
  return switch (name) {
    'surveyShown' => SurveyShown(
        survey: decodeSurvey(payload['survey']),
        trigger: _trigger(payload['trigger']),
      ),
    'surveyNotShown' => SurveyNotShown(
        surveyId: _text(payload['survey_id']),
        reason: _text(payload['reason']),
      ),
    'questionAnswered' => QuestionAnswered(
        surveyId: _text(payload['survey_id']),
        questionId: _text(payload['question_id']),
        type: _text(payload['type']),
        title: _text(payload['title']),
        value: _plain(payload['value']),
      ),
    'surveyCompleted' => SurveyCompleted(
        surveyId: _text(payload['survey_id']),
        responseId: _text(payload['response_id']),
        answers: List.unmodifiable([
          if (payload['answers'] case final List<Object?> answers)
            for (final answer in answers)
              if (answer is Map) _answer(answer),
        ]),
      ),
    'surveyDismissed' => SurveyDismissed(
        surveyId: _text(payload['survey_id']),
      ),
    'surveyError' => SurveyError(
        surveyId: _text(payload['survey_id']),
        code: _text(payload['code']),
        message: _text(payload['message']),
      ),
    _ => null,
  };
}

ResponslySurvey decodeSurvey(Object? survey) => ResponslySurvey(
      id: survey is Map ? _text(survey['id']) : '',
      name: survey is Map ? _text(survey['name']) : '',
    );

ResponslyTrigger _trigger(Object? trigger) => ResponslyTrigger(
      type: trigger is Map ? _text(trigger['type']) : '',
      // iOS leaves the key out and Android sends null when there is no name.
      name: trigger is Map && trigger['name'] is String
          ? trigger['name'] as String
          : null,
    );

ResponslyAnswer _answer(Map<Object?, Object?> answer) => ResponslyAnswer(
      questionId: _text(answer['question_id']),
      type: _text(answer['type']),
      title: _text(answer['title']),
      value: _plain(answer['value']),
    );

String _text(Object? value) => value is String ? value : '';

/// An answer value with the channel's `Map<Object?, Object?>` turned into
/// `Map<String, Object?>` all the way down, so it can be used like decoded JSON.
Object? _plain(Object? value) => switch (value) {
      Map() => <String, Object?>{
          for (final MapEntry(:key, value: item) in value.entries)
            '$key': _plain(item),
        },
      List() => <Object?>[for (final item in value) _plain(item)],
      _ => value,
    };
