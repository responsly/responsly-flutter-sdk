import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

import 'native_side.dart';

void main() {
  final native = NativeSide();
  setUp(native.install);

  group('handshake', () {
    test('the first call is preceded by one attach', () async {
      await Responsly.pause();
      await Responsly.resume();

      expect(native.calls.map((call) => call.method),
          ['attach', 'pause', 'resume']);
    });

    test('listening to events attaches without any other call', () async {
      final subscription = Responsly.events.listen((_) {});
      await pumpEventQueue();

      expect(native.calls.map((call) => call.method), ['attach']);
      await subscription.cancel();
    });
  });

  group('initialize', () {
    test('sends the key with the default options', () async {
      await Responsly.initialize('rsk_test');

      expect(native.argumentsOf('initialize'), {
        'sdk_key': 'rsk_test',
        'api_host': 'https://api.responsly.com',
        'log_level': 'error',
      });
    });

    test('sends the API host and the log level', () async {
      await Responsly.initialize(
        'rsk_test',
        options: const ResponslyOptions(
          apiHost: 'http://10.0.2.2:8000',
          logLevel: ResponslyLogLevel.debug,
        ),
      );

      expect(native.argumentsOf('initialize'), {
        'sdk_key': 'rsk_test',
        'api_host': 'http://10.0.2.2:8000',
        'log_level': 'debug',
      });
    });

    test('every log level goes by its protocol name', () async {
      for (final level in ResponslyLogLevel.values) {
        await Responsly.initialize('rsk_test',
            options: ResponslyOptions(logLevel: level));
      }

      expect(
        native.apiCalls.map((call) => (call.arguments as Map)['log_level']),
        ['none', 'error', 'info', 'debug'],
      );
    });
  });

  group('identify', () {
    test('sends the user ID and the traits', () async {
      await Responsly.identify('user-123', traits: {
        'plan': 'pro',
        'seats': 5,
        'ratio': 0.5,
        'beta': true,
        'signed_up': DateTime.utc(2026, 11, 10, 12),
      });

      expect(native.argumentsOf('identify'), {
        'user_id': 'user-123',
        'traits': {
          'plan': 'pro',
          'seats': 5,
          'ratio': 0.5,
          'beta': true,
          'signed_up': '2026-11-10T12:00:00Z',
        },
      });
    });

    test('sends an empty map without traits', () async {
      await Responsly.identify('user-123');

      expect(native.argumentsOf('identify'),
          {'user_id': 'user-123', 'traits': <String, Object?>{}});
    });
  });

  test('setAttributes sends the traits and keeps null', () async {
    await Responsly.setAttributes({'plan': 'team', 'beta': null});

    final arguments = native.argumentsOf('setAttributes') as Map;
    expect(arguments, {
      'traits': {'plan': 'team', 'beta': null},
    });
    expect((arguments['traits'] as Map).containsKey('beta'), isTrue);
  });

  group('track', () {
    test('sends the event and its properties', () async {
      await Responsly.track('purchase_completed', properties: {
        'value': 49.9,
        'category': 'books',
        'at': DateTime.utc(2026, 1, 2, 3, 4, 5),
      });

      expect(native.argumentsOf('track'), {
        'event': 'purchase_completed',
        'properties': {
          'value': 49.9,
          'category': 'books',
          'at': '2026-01-02T03:04:05Z',
        },
      });
    });

    test('sends an empty map without properties', () async {
      await Responsly.track('app_opened');

      expect(native.argumentsOf('track'),
          {'event': 'app_opened', 'properties': <String, Object?>{}});
    });

    test('accepts a map of non-nullable values', () async {
      const Map<String, Object> properties = {'value': 1};
      await Responsly.track('purchase_completed', properties: properties);

      expect((native.argumentsOf('track') as Map)['properties'], {'value': 1});
    });
  });

  test('screen sends the name', () async {
    await Responsly.screen('Checkout');

    expect(native.argumentsOf('screen'), {'name': 'Checkout'});
  });

  group('showSurvey', () {
    test('sends the Survey ID with the defaults', () async {
      await Responsly.showSurvey('AbCd1234');

      expect(native.argumentsOf('showSurvey'), {
        'survey_id': 'AbCd1234',
        'force': false,
        'hidden_fields': <String, String>{},
        'locale': null,
        'presentation': null,
      });
    });

    test('sends every option', () async {
      await Responsly.showSurvey(
        'AbCd1234',
        force: true,
        hiddenFields: {'order_id': 'A-77'},
        locale: 'pl',
        presentation: ResponslyPresentation.dialog,
      );

      expect(native.argumentsOf('showSurvey'), {
        'survey_id': 'AbCd1234',
        'force': true,
        'hidden_fields': {'order_id': 'A-77'},
        'locale': 'pl',
        'presentation': 'dialog',
      });
    });

    test('every presentation goes by its protocol name', () async {
      for (final presentation in ResponslyPresentation.values) {
        await Responsly.showSurvey('AbCd1234', presentation: presentation);
      }

      expect(
        native.apiCalls.map((call) => (call.arguments as Map)['presentation']),
        ['bottom_sheet', 'dialog', 'fullscreen'],
      );
    });
  });

  test('closeSurvey, pause, resume and reset send no arguments', () async {
    await Responsly.closeSurvey();
    await Responsly.pause();
    await Responsly.resume();
    await Responsly.reset();

    expect(native.apiCalls.map((call) => call.method),
        ['closeSurvey', 'pause', 'resume', 'reset']);
    expect(native.apiCalls.map((call) => call.arguments), everyElement(isNull));
  });

  test('setLocale sends the tag, and null for the device language', () async {
    await Responsly.setLocale('pl');
    await Responsly.setLocale(null);

    expect(native.apiCalls.map((call) => call.arguments), [
      {'locale': 'pl'},
      {'locale': null},
    ]);
  });

  test('setHiddenFields sends the map', () async {
    await Responsly.setHiddenFields({'order_id': 'A-77'});

    expect(native.argumentsOf('setHiddenFields'), {
      'fields': {'order_id': 'A-77'},
    });
  });

  test('setTrackingEnabled sends the flag', () async {
    await Responsly.setTrackingEnabled(false);
    await Responsly.setTrackingEnabled(true);

    expect(native.apiCalls.map((call) => call.arguments), [
      {'enabled': false},
      {'enabled': true},
    ]);
  });

  test('setDisplayGuard tells the native side whether there is a guard',
      () async {
    await Responsly.setDisplayGuard((survey) async => true);
    await Responsly.setDisplayGuard(null);

    expect(native.apiCalls.map((call) => call.method),
        ['setDisplayGuard', 'setDisplayGuard']);
    expect(native.apiCalls.map((call) => call.arguments), [
      {'enabled': true},
      {'enabled': false},
    ]);
  });

  test('calls that are not awaited reach the native side in order', () async {
    Responsly.setTrackingEnabled(true);
    Responsly.initialize('rsk_test');
    Responsly.identify('user-123');
    Responsly.track('purchase_completed');
    Responsly.screen('Checkout');
    Responsly.showSurvey('AbCd1234');
    await pumpEventQueue();

    expect(native.calls.map((call) => call.method), [
      'attach',
      'setTrackingEnabled',
      'initialize',
      'identify',
      'track',
      'screen',
      'showSurvey',
    ]);
  });

  group('errors never reach the app', () {
    test('without the native plugin every call completes normally', () async {
      native.uninstall();

      await expectLater(Responsly.initialize('rsk_test'), completes);
      await expectLater(Responsly.track('purchase_completed'), completes);
      await expectLater(
          Responsly.setDisplayGuard((survey) async => true), completes);
      final subscription = Responsly.events.listen((_) {});
      await pumpEventQueue();
      await subscription.cancel();
    });

    test('a native error completes normally', () async {
      native.failEveryCall();

      await expectLater(Responsly.screen('Checkout'), completes);
      expect(native.calls.map((call) => call.method), ['attach', 'screen']);
    });
  });
}
