import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/src/codec.dart';

enum _Plan { pro }

void main() {
  group('dates', () {
    test('are ISO 8601 in UTC with seconds precision', () {
      expect(
          encodeDate(DateTime.utc(2026, 11, 10, 12)), '2026-11-10T12:00:00Z');
      expect(encodeDate(DateTime.utc(2026, 1, 2, 3, 4, 5)),
          '2026-01-02T03:04:05Z');
    });

    test('drop milliseconds and microseconds', () {
      expect(encodeDate(DateTime.utc(2026, 11, 10, 12, 0, 0, 999, 999)),
          '2026-11-10T12:00:00Z');
      expect(encodeDate(DateTime.utc(2026, 12, 31, 23, 59, 59, 999)),
          '2026-12-31T23:59:59Z');
    });

    test('convert local time to UTC', () {
      final local = DateTime(2026, 11, 10, 12, 30, 15);

      expect(encodeDate(local), encodeDate(local.toUtc()));
      expect(DateTime.parse(encodeDate(local)), local.toUtc());
    });

    test('before 1970 round down like every other date', () {
      expect(encodeDate(DateTime.utc(1969, 12, 31, 23, 59, 59, 500)),
          '1969-12-31T23:59:59Z');
    });

    test('pad the year to four digits', () {
      expect(
          encodeDate(DateTime.utc(987, 6, 5, 4, 3, 2)), '0987-06-05T04:03:02Z');
    });
  });

  group('values', () {
    test('strings, numbers and booleans go as they are', () {
      expect(encodeValues({'s': 'pro', 'i': 5, 'd': 49.9, 'b': true}),
          {'s': 'pro', 'i': 5, 'd': 49.9, 'b': true});
      expect(encodeValue(5), isA<int>());
      expect(encodeValue(5.0), isA<double>());
    });

    test('null is kept, so it can remove a trait', () {
      final encoded = encodeValues({'beta': null});

      expect(encoded.containsKey('beta'), isTrue);
      expect(encoded['beta'], isNull);
    });

    test('a DateTime becomes a string', () {
      expect(encodeValues({'signed_up': DateTime.utc(2026, 11, 10, 12)}),
          {'signed_up': '2026-11-10T12:00:00Z'});
    });

    test('anything else goes as its toString()', () {
      expect(
        encodeValues({
          'plan': _Plan.pro,
          'duration': const Duration(seconds: 90),
          'tags': ['a', 'b'],
        }),
        {'plan': '_Plan.pro', 'duration': '0:01:30.000000', 'tags': '[a, b]'},
      );
    });

    test('the map that was passed in is not changed', () {
      final traits = <String, Object?>{'signed_up': DateTime.utc(2026)};
      encodeValues(traits);

      expect(traits['signed_up'], isA<DateTime>());
    });
  });
}
