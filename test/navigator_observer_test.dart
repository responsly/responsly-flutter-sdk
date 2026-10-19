import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsly_sdk/responsly_sdk.dart';

import 'native_side.dart';

void main() {
  final native = NativeSide();
  setUp(native.install);

  List<Object?> screens() => native.calls
      .where((call) => call.method == 'screen')
      .map((call) => (call.arguments as Map)['name'])
      .toList();

  Future<NavigatorState> pumpApp(WidgetTester tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [ResponslyNavigatorObserver()],
      routes: {
        '/': (context) => const Text('home'),
        '/checkout': (context) => const Text('checkout'),
        '/thanks': (context) => const Text('thanks'),
      },
    ));
    return navigator.currentState!;
  }

  MaterialPageRoute<void> route(String? name) => MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (context) => Text(name ?? 'unnamed'),
      );

  testWidgets('reports the first route', (tester) async {
    await pumpApp(tester);

    expect(screens(), ['/']);
  });

  testWidgets('reports a pushed route by its name', (tester) async {
    final navigator = await pumpApp(tester);
    navigator.pushNamed('/checkout');
    await tester.pumpAndSettle();
    navigator.push(route('Order details'));
    await tester.pumpAndSettle();

    expect(screens(), ['/', '/checkout', 'Order details']);
  });

  testWidgets('reports the route that is revealed by a pop', (tester) async {
    final navigator = await pumpApp(tester);
    navigator.pushNamed('/checkout');
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(screens(), ['/', '/checkout', '/']);
  });

  testWidgets('removing the active route reports the screen revealed below it',
      (tester) async {
    final navigator = await pumpApp(tester);
    final checkout = route('Checkout');
    navigator.push(checkout);
    await tester.pumpAndSettle();

    navigator.removeRoute(checkout);
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(screens(), ['/', 'Checkout', '/']);
  });

  testWidgets('removing a route in the background keeps the active screen',
      (tester) async {
    final navigator = await pumpApp(tester);
    final home = ModalRoute.of(tester.element(find.text('home')))!;
    navigator.pushNamed('/checkout');
    await tester.pumpAndSettle();

    navigator.removeRoute(home);
    await tester.pumpAndSettle();

    expect(find.text('checkout'), findsOneWidget);
    expect(screens(), ['/', '/checkout']);
  });

  testWidgets('reports the new route of a replace', (tester) async {
    final navigator = await pumpApp(tester);
    navigator.pushNamed('/checkout');
    await tester.pumpAndSettle();
    navigator.pushReplacementNamed('/thanks');
    await tester.pumpAndSettle();

    expect(screens(), ['/', '/checkout', '/thanks']);
  });

  testWidgets('replacing a route in the background keeps the active screen',
      (tester) async {
    final navigator = await pumpApp(tester);
    final home = ModalRoute.of(tester.element(find.text('home')))!;
    navigator.pushNamed('/checkout');
    await tester.pumpAndSettle();

    navigator.replace(oldRoute: home, newRoute: route('Updated home'));
    await tester.pumpAndSettle();

    expect(find.text('checkout'), findsOneWidget);
    expect(screens(), ['/', '/checkout']);
  });

  testWidgets('skips routes without a name', (tester) async {
    final navigator = await pumpApp(tester);
    navigator.push(route(null));
    await tester.pumpAndSettle();
    navigator.push(route(''));
    await tester.pumpAndSettle();

    expect(screens(), ['/']);
  });

  testWidgets('skips a pop that reveals a route without a name',
      (tester) async {
    final navigator = await pumpApp(tester);
    navigator.push(route(null));
    await tester.pumpAndSettle();
    navigator.push(route('Checkout'));
    await tester.pumpAndSettle();
    navigator.pop();
    await tester.pumpAndSettle();

    expect(screens(), ['/', 'Checkout']);
  });

  testWidgets('replacing the active route reports the replacement',
      (tester) async {
    final navigator = await pumpApp(tester);
    final home = ModalRoute.of(tester.element(find.text('home')))!;

    navigator.replace(oldRoute: home, newRoute: route('New'));
    await tester.pumpAndSettle();

    expect(screens(), ['/', 'New']);
  });

  test('didReplace and didPop without a route report nothing', () {
    ResponslyNavigatorObserver()
      ..didReplace(oldRoute: route('Old'))
      ..didPop(route('Popped'), null);

    expect(screens(), isEmpty);
  });
}
