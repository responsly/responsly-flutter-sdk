import 'package:flutter/foundation.dart';

/// A survey, as passed to the display guard and included in [SurveyShown].
@immutable
class ResponslySurvey {
  const ResponslySurvey({required this.id, required this.name});

  /// The Survey ID.
  final String id;

  /// The form's name in Responsly.
  final String name;

  @override
  String toString() => 'ResponslySurvey(id: $id, name: $name)';
}

/// What caused a survey to be shown.
@immutable
class ResponslyTrigger {
  const ResponslyTrigger({required this.type, this.name});

  /// `event`, `screen`, `app_launch`, or `manual` for `Responsly.showSurvey`.
  final String type;

  /// The event or screen name; `null` for `app_launch` and `manual`.
  final String? name;

  @override
  String toString() => 'ResponslyTrigger(type: $type, name: $name)';
}

/// One answer of a completed survey.
@immutable
class ResponslyAnswer {
  const ResponslyAnswer({
    required this.questionId,
    required this.type,
    required this.title,
    required this.value,
  });

  /// The question's ID.
  final String questionId;

  /// The question's type, for example `nps`, `rating`, `multiple_choice`, `text`.
  final String type;

  /// The question text as shown to the respondent.
  final String title;

  /// The answer as the survey stores it: a `String`, a `num`, a `bool`, a `List<Object?>` or a
  /// `Map<String, Object?>`. Number scales such as NPS give a number.
  final Object? value;

  @override
  String toString() =>
      'ResponslyAnswer(questionId: $questionId, type: $type, title: $title, value: $value)';
}

/// What happened to a survey. Delivered by `Responsly.events`.
///
/// The class is sealed, so a `switch` over an event is checked for completeness:
///
/// ```dart
/// Responsly.events.listen((event) {
///   switch (event) {
///     case SurveyShown(:final survey):
///       debugPrint('shown ${survey.id}');
///     case SurveyNotShown(:final surveyId, :final reason):
///       debugPrint('not shown $surveyId: $reason');
///     case QuestionAnswered():
///     case SurveyCompleted():
///     case SurveyDismissed():
///     case SurveyError():
///       break;
///   }
/// });
/// ```
@immutable
sealed class ResponslyEvent {
  const ResponslyEvent();
}

/// The survey became visible.
final class SurveyShown extends ResponslyEvent {
  const SurveyShown({required this.survey, required this.trigger});

  final ResponslySurvey survey;
  final ResponslyTrigger trigger;

  @override
  String toString() => 'SurveyShown(survey: $survey, trigger: $trigger)';
}

/// A survey matched a trigger, or was requested with `Responsly.showSurvey`, but was not shown.
final class SurveyNotShown extends ResponslyEvent {
  const SurveyNotShown({required this.surveyId, required this.reason});

  final String surveyId;

  /// Why, as one of the not-shown reasons of the SDK, for example `frequency_limit`,
  /// `audience_mismatch` or `vetoed`. The list is in the
  /// [documentation](https://developers.responsly.com/mobile-sdk/testing/#not-shown-reasons).
  final String reason;

  @override
  String toString() => 'SurveyNotShown(surveyId: $surveyId, reason: $reason)';
}

/// The respondent answered a question. Fires before the survey is submitted.
final class QuestionAnswered extends ResponslyEvent {
  const QuestionAnswered({
    required this.surveyId,
    required this.questionId,
    required this.type,
    required this.title,
    required this.value,
  });

  final String surveyId;
  final String questionId;

  /// The question's type, for example `nps`, `rating`, `multiple_choice`, `text`.
  final String type;

  /// The question text as shown to the respondent.
  final String title;

  /// The answer; see [ResponslyAnswer.value].
  final Object? value;

  @override
  String toString() =>
      'QuestionAnswered(surveyId: $surveyId, questionId: $questionId, type: $type, title: $title, value: $value)';
}

/// The respondent submitted the survey.
final class SurveyCompleted extends ResponslyEvent {
  const SurveyCompleted({
    required this.surveyId,
    required this.responseId,
    required this.answers,
  });

  final String surveyId;

  /// The ID of the saved response.
  final String responseId;

  final List<ResponslyAnswer> answers;

  @override
  String toString() =>
      'SurveyCompleted(surveyId: $surveyId, responseId: $responseId, answers: $answers)';
}

/// The survey was closed before it was completed.
final class SurveyDismissed extends ResponslyEvent {
  const SurveyDismissed({required this.surveyId});

  final String surveyId;

  @override
  String toString() => 'SurveyDismissed(surveyId: $surveyId)';
}

/// The survey reported an error while it was visible.
final class SurveyError extends ResponslyEvent {
  const SurveyError({
    required this.surveyId,
    required this.code,
    required this.message,
  });

  final String surveyId;

  /// A short error code.
  final String code;

  /// A description for logs. Do not show it to users.
  final String message;

  @override
  String toString() =>
      'SurveyError(surveyId: $surveyId, code: $code, message: $message)';
}
