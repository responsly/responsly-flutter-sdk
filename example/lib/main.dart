import 'dart:async';

import 'package:flutter/material.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Responsly SDK example',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF3F51B5)),
      home: const ControlPanel(),
    );
  }
}

/// Every call of the SDK behind a button, and every event in a log.
class ControlPanel extends StatefulWidget {
  const ControlPanel({super.key});

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  final _sdkKey = TextEditingController(text: 'rsk_demo');
  final _apiHost = TextEditingController(text: ResponslyOptions.defaultApiHost);
  final _surveyId = TextEditingController();
  final _log = <String>[];

  bool _force = false;
  late final StreamSubscription<ResponslyEvent> _events;

  @override
  void initState() {
    super.initState();
    _events = Responsly.events.listen((event) => _addToLog(_describe(event)));
  }

  @override
  void dispose() {
    _events.cancel();
    _sdkKey.dispose();
    _apiHost.dispose();
    _surveyId.dispose();
    super.dispose();
  }

  static String _describe(ResponslyEvent event) {
    return switch (event) {
      SurveyShown(:final survey, :final trigger) =>
        'surveyShown ${survey.id} "${survey.name}" trigger=${trigger.type}'
            '${trigger.name == null ? '' : ' (${trigger.name})'}',
      SurveyNotShown(:final surveyId, :final reason) =>
        'surveyNotShown $surveyId reason=$reason',
      QuestionAnswered(
        :final surveyId,
        :final questionId,
        :final type,
        :final value,
      ) =>
        'questionAnswered $surveyId $questionId ($type) = $value',
      SurveyCompleted(:final surveyId, :final responseId, :final answers) =>
        'surveyCompleted $surveyId response=$responseId '
            'answers=${answers.map((answer) => '${answer.questionId}=${answer.value}').join(', ')}',
      SurveyDismissed(:final surveyId) => 'surveyDismissed $surveyId',
      SurveyError(:final surveyId, :final code, :final message) =>
        'surveyError $surveyId $code: $message',
    };
  }

  void _addToLog(String line) {
    debugPrint('[ResponslyExample] $line');
    if (!mounted) return;
    final now = TimeOfDay.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
    setState(() => _log.insert(0, '$time  $line'));
  }

  void _initialize() {
    final apiHost = _apiHost.text.trim();
    Responsly.initialize(
      _sdkKey.text.trim(),
      options: ResponslyOptions(
        apiHost: apiHost.isEmpty ? ResponslyOptions.defaultApiHost : apiHost,
        logLevel: ResponslyLogLevel.debug,
      ),
    );
    _addToLog('→ initialize ${_sdkKey.text.trim()}');
  }

  void _identify() {
    Responsly.identify(
      'demo-user',
      traits: {
        'plan': 'pro',
        'seats': 5,
        'beta': true,
        'signed_up': DateTime.now(),
      },
    );
    _addToLog('→ identify demo-user');
  }

  void _track() {
    Responsly.track('purchase_completed', properties: {'value': 49.9});
    _addToLog('→ track purchase_completed');
  }

  void _screen() {
    Responsly.screen('Checkout');
    _addToLog('→ screen Checkout');
  }

  void _showSurvey() {
    final surveyId = _surveyId.text.trim();
    Responsly.showSurvey(surveyId, force: _force);
    _addToLog('→ showSurvey $surveyId${_force ? ' (force)' : ''}');
  }

  void _run(String name, Future<void> Function() call) {
    call();
    _addToLog('→ $name');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Responsly SDK example')),
      body: SafeArea(
        child: Column(
          children: [
            Flexible(
              flex: 3,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildControls(),
              ),
            ),
            const Divider(height: 1),
            Expanded(flex: 2, child: _buildLog(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('sdkKey'),
          controller: _sdkKey,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'SDK key'),
        ),
        TextField(
          key: const Key('apiHost'),
          controller: _apiHost,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'API host'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilledButton(
              key: const Key('initialize'),
              onPressed: _initialize,
              child: const Text('Initialize'),
            ),
            OutlinedButton(
              key: const Key('identify'),
              onPressed: _identify,
              child: const Text('Identify demo user'),
            ),
            OutlinedButton(
              key: const Key('track'),
              onPressed: _track,
              child: const Text('Track purchase_completed'),
            ),
            OutlinedButton(
              key: const Key('screen'),
              onPressed: _screen,
              child: const Text('Screen Checkout'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('surveyId'),
                controller: _surveyId,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Survey ID'),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Force'),
            Switch(
              key: const Key('force'),
              value: _force,
              onChanged: (value) => setState(() => _force = value),
            ),
            FilledButton.tonal(
              key: const Key('showSurvey'),
              onPressed: _showSurvey,
              child: const Text('Show survey'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton(
              key: const Key('pause'),
              onPressed: () => _run('pause', Responsly.pause),
              child: const Text('Pause'),
            ),
            OutlinedButton(
              key: const Key('resume'),
              onPressed: () => _run('resume', Responsly.resume),
              child: const Text('Resume'),
            ),
            OutlinedButton(
              key: const Key('close'),
              onPressed: () => _run('closeSurvey', Responsly.closeSurvey),
              child: const Text('Close'),
            ),
            OutlinedButton(
              key: const Key('reset'),
              onPressed: () => _run('reset', Responsly.reset),
              child: const Text('Reset'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLog(BuildContext context) {
    if (_log.isEmpty) {
      return const Center(child: Text('Events appear here.'));
    }
    return ListView.builder(
      key: const Key('log'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _log.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          _log[index],
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontFamily: 'monospace'),
        ),
      ),
    );
  }
}
