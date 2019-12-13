import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:provider/src/inherited_provider.dart';

import 'common.dart';

class Context extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}

BuildContext get context => find.byType(Context).evaluate().single;

T of<T>([BuildContext c]) => Provider.of<T>(c ?? context, listen: false);

void main() {
  group('diagnostics', () {
    testWidgets('InheritedProvider.value', (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: (_, __) => throw Error(),
          child: Container(),
        ),
      );

      final rootElement = tester.allElements.first;

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(value: 42)'),
      );

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: (_, __) => () {},
          child: const TextOf<int>(),
        ),
      );

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(value: 42, listening to value)'),
      );
    });
    testWidgets("InheritedProvider doesn't break lazy loading", (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>(
          create: (_) => 42,
          child: Container(),
        ),
      );

      final rootElement = tester.allElements.first;

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(value: <not yet loaded>)'),
      );

      Provider.of<int>(tester.element(find.byType(Container)));

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(value: 42)'),
      );
    });
    testWidgets('InheritedProvider show if listening', (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>(
          create: (_) => 24,
          startListening: (_, __) => () {},
          child: Container(),
        ),
      );

      final rootElement = tester.allElements.first;

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(value: <not yet loaded>)'),
      );

      Provider.of<int>(tester.element(find.byType(Container)));

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(value: 24, listening to value)'),
      );
    });
    testWidgets('DeferredInheritedProvider.value', (tester) async {
      await tester.pumpWidget(
        DeferredInheritedProvider<int, int>.value(
          value: 42,
          startListening: (_, setState, __, ___) {
            setState(24);
            return () {};
          },
          child: Container(),
        ),
      );

      final rootElement = tester.allElements.first;

      expect(
        rootElement.toString(),
        contains(
          'InheritedProvider<int>(controller: 42, value: <not yet loaded>)',
        ),
      );

      Provider.of<int>(tester.element(find.byType(Container)));

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(controller: 42, value: 24)'),
      );
    });
    testWidgets('DeferredInheritedProvider', (tester) async {
      await tester.pumpWidget(
        DeferredInheritedProvider<int, int>(
          create: (_) => 42,
          startListening: (_, setState, __, ___) {
            setState(24);
            return () {};
          },
          child: Container(),
        ),
      );

      final rootElement = tester.allElements.first;

      expect(
        rootElement.toString(),
        contains(
          '''
InheritedProvider<int>(controller: <not yet loaded>, value: <not yet loaded>)''',
        ),
      );

      Provider.of<int>(tester.element(find.byType(Container)));

      expect(
        rootElement.toString(),
        contains('InheritedProvider<int>(controller: 42, value: 24)'),
      );
    });
  });
  testWidgets('isBuilding', (tester) async {
    expect(isWidgetTreeBuilding, isFalse);

    bool valueDuringBuild;
    await tester.pumpWidget(
      InheritedProvider.value(
        value: 42,
        child: Builder(
          builder: (_) {
            valueDuringBuild = isWidgetTreeBuilding;
            return Container();
          },
        ),
      ),
    );

    expect(valueDuringBuild, isTrue);
    expect(isWidgetTreeBuilding, isFalse);

    tester.element(find.byType(Builder)).markNeedsBuild();

    await tester.pump();

    expect(valueDuringBuild, isTrue);
    expect(isWidgetTreeBuilding, isFalse);

    // remove the listener
    await tester.pumpWidget(Container());

    expect(isWidgetTreeBuilding, isFalse);

    await tester.pumpWidget(
      Builder(
        builder: (_) {
          valueDuringBuild = isWidgetTreeBuilding;
          return Container();
        },
      ),
    );

    // the listener was removed so it doesn't update anymore
    expect(valueDuringBuild, isFalse);
    expect(isWidgetTreeBuilding, isFalse);
  });
  test('autoDeferred crash', () {
    expect(
      () => autoDeferred<int, int>(
        create: (_) => 42,
        value: 42,
        startListening: (_, __, ___, ____) => () {},
        child: Container(),
      ),
      throwsAssertionError,
    );
    expect(
      () => autoDeferred<int, int>(
        create: null,
        value: 42,
        dispose: (_, __) {},
        startListening: (_, __, ___, ____) => () {},
        child: Container(),
      ),
      throwsAssertionError,
    );
  });
  group('InheritedProvider.value()', () {
    testWidgets('markNeedsNotifyDependents during startListening is noop',
        (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: (e, value) {
            e.markNeedsNotifyDependents();
            return () {};
          },
          child: const TextOf<int>(),
        ),
      );
    });
    testWidgets('startListening called again when create returns new value',
        (tester) async {
      final stopListening = StopListeningMock();
      final startListening = StartListeningMock<int>(stopListening);

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: startListening,
          child: const TextOf<int>(),
        ),
      );

      final element = tester.element<InheritedProviderElement<int>>(
          find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      verify(startListening(element, 42)).called(1);
      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);

      final stopListening2 = StopListeningMock();
      final startListening2 = StartListeningMock<int>(stopListening2);

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 24,
          startListening: startListening2,
          child: const TextOf<int>(),
        ),
      );

      verifyNoMoreInteractions(startListening);
      verifyInOrder([
        stopListening(),
        startListening2(element, 24),
      ]);
      verifyNoMoreInteractions(startListening2);
      verifyZeroInteractions(stopListening2);

      await tester.pumpWidget(Container());

      verifyNoMoreInteractions(startListening);
      verify(stopListening2()).called(1);
    });
    testWidgets('startListening', (tester) async {
      final stopListening = StopListeningMock();
      final startListening = StartListeningMock<int>(stopListening);

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: startListening,
          child: Container(),
        ),
      );

      verifyZeroInteractions(startListening);

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: startListening,
          child: const TextOf<int>(),
        ),
      );

      final element = tester.element<InheritedProviderElement<int>>(
          find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      verify(startListening(element, 42)).called(1);
      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: startListening,
          child: const TextOf<int>(),
        ),
      );

      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);

      await tester.pumpWidget(Container());

      verifyNoMoreInteractions(startListening);
      verify(stopListening()).called(1);
    });
    testWidgets(
      "stopListening not called twice if rebuild doesn't have listeners",
      (tester) async {
        final stopListening = StopListeningMock();
        final startListening = StartListeningMock<int>(stopListening);

        await tester.pumpWidget(
          InheritedProvider<int>.value(
            value: 42,
            startListening: startListening,
            child: const TextOf<int>(),
          ),
        );
        verify(startListening(argThat(isNotNull), 42)).called(1);
        verifyZeroInteractions(stopListening);

        final stopListening2 = StopListeningMock();
        final startListening2 = StartListeningMock<int>(stopListening2);
        await tester.pumpWidget(
          InheritedProvider<int>.value(
            value: 24,
            startListening: startListening2,
            child: Container(),
          ),
        );

        verifyNoMoreInteractions(startListening);
        verify(stopListening()).called(1);
        verifyZeroInteractions(startListening2);
        verifyZeroInteractions(stopListening2);

        await tester.pumpWidget(Container());

        verifyNoMoreInteractions(startListening);
        verifyNoMoreInteractions(stopListening);
        verifyZeroInteractions(startListening2);
        verifyZeroInteractions(stopListening2);
      },
    );

    testWidgets('removeListener cannot be null', (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          startListening: (_, __) => null,
          child: const TextOf<int>(),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });

    testWidgets('pass down current value', (tester) async {
      int value;
      final child = Consumer<int>(
        builder: (_, v, __) {
          value = v;
          return Container();
        },
      );

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 42, child: child),
      );

      expect(value, equals(42));

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 43, child: child),
      );

      expect(value, equals(43));
    });
    testWidgets('default updateShouldNotify', (tester) async {
      var buildCount = 0;

      final child = Consumer<int>(builder: (_, __, ___) {
        buildCount++;
        return Container();
      });

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 42, child: child),
      );
      expect(buildCount, equals(1));

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 42, child: child),
      );
      expect(buildCount, equals(1));

      await tester.pumpWidget(
        InheritedProvider<int>.value(value: 43, child: child),
      );
      expect(buildCount, equals(2));
    });
    testWidgets('custom updateShouldNotify', (tester) async {
      var buildCount = 0;
      final updateShouldNotify = UpdateShouldNotifyMock<int>();

      final child = Consumer<int>(builder: (_, __, ___) {
        buildCount++;
        return Container();
      });

      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 42,
          updateShouldNotify: updateShouldNotify,
          child: child,
        ),
      );
      expect(buildCount, equals(1));
      verifyZeroInteractions(updateShouldNotify);

      when(updateShouldNotify(any, any)).thenReturn(false);
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 43,
          updateShouldNotify: updateShouldNotify,
          child: child,
        ),
      );
      expect(buildCount, equals(1));
      verify(updateShouldNotify(42, 43))..called(1);

      when(updateShouldNotify(any, any)).thenReturn(true);
      await tester.pumpWidget(
        InheritedProvider<int>.value(
          value: 44,
          updateShouldNotify: updateShouldNotify,
          child: child,
        ),
      );
      expect(buildCount, equals(2));
      verify(updateShouldNotify(43, 44))..called(1);

      verifyNoMoreInteractions(updateShouldNotify);
    });
  });
  group('InheritedProvider()', () {
    testWidgets('markNeedsNotifyDependents during startListening is noop',
        (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 24,
          startListening: (e, value) {
            e.markNeedsNotifyDependents();
            return () {};
          },
          child: const TextOf<int>(),
        ),
      );
    });
    testWidgets(
      'update can obtain parent of the same type than self',
      (tester) async {
        await tester.pumpWidget(
          InheritedProvider<String>.value(
            value: 'root',
            child: InheritedProvider<String>(
              update: (context, _) {
                return Provider.of(context);
              },
              child: const TextOf<String>(),
            ),
          ),
        );

        expect(find.text('root'), findsOneWidget);
      },
    );
    testWidgets('_debugCheckInvalidValueType', (tester) async {
      final checkType = DebugCheckValueTypeMock<int>();

      await tester.pumpWidget(
        InheritedProvider<int>(
          create: (_) => 0,
          update: (_, __) => 1,
          debugCheckInvalidValueType: checkType,
          child: const TextOf<int>(),
        ),
      );

      verifyInOrder([
        checkType(0),
        checkType(1),
      ]);
      verifyNoMoreInteractions(checkType);

      await tester.pumpWidget(
        InheritedProvider<int>(
          create: (_) => 0,
          update: (_, __) => 1,
          debugCheckInvalidValueType: checkType,
          child: const TextOf<int>(),
        ),
      );

      verifyNoMoreInteractions(checkType);

      await tester.pumpWidget(
        InheritedProvider<int>(
          create: (_) => 0,
          update: (_, __) => 2,
          debugCheckInvalidValueType: checkType,
          child: const TextOf<int>(),
        ),
      );

      verify(checkType(2)).called(1);
      verifyNoMoreInteractions(checkType);
    });
    testWidgets('startListening', (tester) async {
      final stopListening = StopListeningMock();
      final startListening = StartListeningMock<int>(stopListening);
      final dispose = DisposeMock<int>();

      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          startListening: startListening,
          dispose: dispose,
          child: const TextOf<int>(),
        ),
      );

      final element = tester.element<InheritedProviderElement<int>>(
          find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      verify(startListening(element, 42)).called(1);
      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);
      verifyZeroInteractions(dispose);

      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          startListening: startListening,
          dispose: dispose,
          child: const TextOf<int>(),
        ),
      );

      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);
      verifyZeroInteractions(dispose);

      await tester.pumpWidget(Container());

      verifyNoMoreInteractions(startListening);
      verifyInOrder([
        stopListening(),
        dispose(element, 42),
      ]);
      verifyNoMoreInteractions(dispose);
      verifyNoMoreInteractions(stopListening);
    });

    testWidgets('startListening called again when create returns new value',
        (tester) async {
      final stopListening = StopListeningMock();
      final startListening = StartListeningMock<int>(stopListening);

      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          startListening: startListening,
          child: const TextOf<int>(),
        ),
      );

      final element = tester.element<InheritedProviderElement<int>>(
          find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      verify(startListening(element, 42)).called(1);
      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);

      final stopListening2 = StopListeningMock();
      final startListening2 = StartListeningMock<int>(stopListening2);

      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 24,
          startListening: startListening2,
          child: const TextOf<int>(),
        ),
      );

      verifyNoMoreInteractions(startListening);
      verifyInOrder([
        stopListening(),
        startListening2(element, 24),
      ]);
      verifyNoMoreInteractions(startListening2);
      verifyZeroInteractions(stopListening2);

      await tester.pumpWidget(Container());

      verifyNoMoreInteractions(startListening);
      verify(stopListening2()).called(1);
    });

    testWidgets(
      "stopListening not called twice if rebuild doesn't have listeners",
      (tester) async {
        final stopListening = StopListeningMock();
        final startListening = StartListeningMock<int>(stopListening);

        await tester.pumpWidget(
          InheritedProvider<int>(
            update: (_, __) => 42,
            startListening: startListening,
            child: const TextOf<int>(),
          ),
        );
        verify(startListening(argThat(isNotNull), 42)).called(1);
        verifyZeroInteractions(stopListening);

        final stopListening2 = StopListeningMock();
        final startListening2 = StartListeningMock<int>(stopListening2);
        await tester.pumpWidget(
          InheritedProvider<int>(
            update: (_, __) => 24,
            startListening: startListening2,
            child: Container(),
          ),
        );

        verifyNoMoreInteractions(startListening);
        verify(stopListening()).called(1);
        verifyZeroInteractions(startListening2);
        verifyZeroInteractions(stopListening2);

        await tester.pumpWidget(Container());

        verifyNoMoreInteractions(startListening);
        verifyNoMoreInteractions(stopListening);
        verifyZeroInteractions(startListening2);
        verifyZeroInteractions(stopListening2);
      },
    );

    testWidgets('removeListener cannot be null', (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          startListening: (_, __) => null,
          child: const TextOf<int>(),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets(
      'fails if initialValueBuilder calls inheritFromElement/inheritFromWiggetOfExactType',
      (tester) async {
        await tester.pumpWidget(
          InheritedProvider<int>.value(
            value: 42,
            child: InheritedProvider<double>(
              create: (context) => Provider.of<int>(context).toDouble(),
              child: Consumer<double>(
                builder: (_, __, ___) => Container(),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isAssertionError);
      },
    );
    testWidgets(
      'builder is called on every rebuild'
      'and after a dependency change',
      (tester) async {
        int lastValue;
        final child = Consumer<int>(
          builder: (_, value, __) {
            lastValue = value;
            return Container();
          },
        );
        final update = ValueBuilderMock<int>();
        when(update(any, any))
            .thenAnswer((i) => (i.positionalArguments[1] as int) * 2);

        await tester.pumpWidget(
          InheritedProvider<int>(
            create: (_) => 42,
            update: update,
            child: Container(),
          ),
        );

        final inheritedElement = tester.element(
          find.byWidgetPredicate((w) => w is InheritedProvider<int>),
        );
        verifyZeroInteractions(update);

        await tester.pumpWidget(
          InheritedProvider<int>(
            create: (_) => 42,
            update: update,
            child: child,
          ),
        );

        verify(update(inheritedElement, 42)).called(1);
        expect(lastValue, equals(84));

        await tester.pumpWidget(
          InheritedProvider<int>(
            create: (_) => 42,
            update: update,
            child: child,
          ),
        );

        verify(update(inheritedElement, 84)).called(1);
        expect(lastValue, equals(168));

        verifyNoMoreInteractions(update);
      },
    );
    testWidgets(
      'builder with no updateShouldNotify use ==',
      (tester) async {
        int lastValue;
        var buildCount = 0;
        final child = Consumer<int>(
          builder: (_, value, __) {
            lastValue = value;
            buildCount++;
            return Container();
          },
        );

        await tester.pumpWidget(
          InheritedProvider<int>(
            create: (_) => null,
            update: (_, __) => 42,
            child: child,
          ),
        );

        expect(lastValue, equals(42));
        expect(buildCount, equals(1));

        await tester.pumpWidget(
          InheritedProvider<int>(
            create: (_) => null,
            update: (_, __) => 42,
            child: child,
          ),
        );

        expect(lastValue, equals(42));
        expect(buildCount, equals(1));

        await tester.pumpWidget(
          InheritedProvider<int>(
            create: (_) => null,
            update: (_, __) => 43,
            child: child,
          ),
        );

        expect(lastValue, equals(43));
        expect(buildCount, equals(2));
      },
    );
    testWidgets(
      'builder calls updateShouldNotify callback',
      (tester) async {
        final updateShouldNotify = UpdateShouldNotifyMock<int>();

        int lastValue;
        var buildCount = 0;
        final child = Consumer<int>(
          builder: (_, value, __) {
            lastValue = value;
            buildCount++;
            return Container();
          },
        );

        await tester.pumpWidget(
          InheritedProvider<int>(
            update: (_, __) => 42,
            updateShouldNotify: updateShouldNotify,
            child: child,
          ),
        );

        verifyZeroInteractions(updateShouldNotify);
        expect(lastValue, equals(42));
        expect(buildCount, equals(1));

        when(updateShouldNotify(any, any)).thenReturn(true);
        await tester.pumpWidget(
          InheritedProvider<int>(
            update: (_, __) => 42,
            updateShouldNotify: updateShouldNotify,
            child: child,
          ),
        );

        verify(updateShouldNotify(42, 42)).called(1);
        expect(lastValue, equals(42));
        expect(buildCount, equals(2));

        when(updateShouldNotify(any, any)).thenReturn(false);
        await tester.pumpWidget(
          InheritedProvider<int>(
            update: (_, __) => 43,
            updateShouldNotify: updateShouldNotify,
            child: child,
          ),
        );

        verify(updateShouldNotify(42, 43)).called(1);
        expect(lastValue, equals(42));
        expect(buildCount, equals(2));

        verifyNoMoreInteractions(updateShouldNotify);
      },
    );
    testWidgets('initialValue is transmitted to valueBuilder', (tester) async {
      int lastValue;
      await tester.pumpWidget(
        InheritedProvider<int>(
          create: (_) => 0,
          update: (_, last) {
            lastValue = last;
            return 42;
          },
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
      expect(lastValue, equals(0));
    });
    testWidgets('calls builder again if dependencies change', (tester) async {
      final valueBuilder = ValueBuilderMock<int>();

      when(valueBuilder(any, any)).thenAnswer((invocation) {
        return int.parse(Provider.of<String>(
          invocation.positionalArguments.first as BuildContext,
        ));
      });

      var buildCount = 0;
      final child = InheritedProvider<int>(
        create: (_) => 0,
        update: valueBuilder,
        child: Consumer<int>(
          builder: (_, value, __) {
            buildCount++;
            return Text(
              value.toString(),
              textDirection: TextDirection.ltr,
            );
          },
        ),
      );

      await tester.pumpWidget(
        InheritedProvider<String>.value(
          value: '42',
          child: child,
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('42'), findsOneWidget);

      await tester.pumpWidget(
        InheritedProvider<String>.value(
          value: '24',
          child: child,
        ),
      );

      expect(buildCount, equals(2));
      expect(find.text('24'), findsOneWidget);

      await tester.pumpWidget(
        InheritedProvider<String>.value(
          value: '24',
          child: child,
          updateShouldNotify: (_, __) => true,
        ),
      );

      expect(buildCount, equals(2));
      expect(find.text('24'), findsOneWidget);
    });
    testWidgets('exposes initialValue if valueBuilder is null', (tester) async {
      await tester.pumpWidget(
        InheritedProvider<int>(
          create: (_) => 42,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
    });
    testWidgets('call dispose on unmount', (tester) async {
      final dispose = DisposeMock<int>();
      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          dispose: dispose,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));

      verifyZeroInteractions(dispose);

      BuildContext context = tester
          .element(find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      await tester.pumpWidget(Container());

      verify(dispose(context, 42)).called(1);
      verifyNoMoreInteractions(dispose);
    });
    testWidgets('builder unmount, dispose not called if value never read',
        (tester) async {
      final dispose = DisposeMock<int>();

      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          dispose: dispose,
          child: Container(),
        ),
      );

      await tester.pumpWidget(Container());

      verifyZeroInteractions(dispose);
    });
    testWidgets('call dispose after new value', (tester) async {
      final dispose = DisposeMock<int>();
      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          dispose: dispose,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));

      final dispose2 = DisposeMock<int>();
      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 42,
          dispose: dispose2,
          child: Container(),
        ),
      );

      verifyZeroInteractions(dispose);
      verifyZeroInteractions(dispose2);

      BuildContext context = tester
          .element(find.byWidgetPredicate((w) => w is InheritedProvider<int>));

      final dispose3 = DisposeMock<int>();
      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, __) => 24,
          dispose: dispose3,
          child: Container(),
        ),
      );

      verifyZeroInteractions(dispose);
      verifyZeroInteractions(dispose3);
      verify(dispose2(context, 42)).called(1);
      verifyNoMoreInteractions(dispose);
    });

    testWidgets('valueBuilder works without initialBuilder', (tester) async {
      int lastValue;
      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, last) {
            lastValue = last;
            return 42;
          },
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
      expect(lastValue, equals(null));

      await tester.pumpWidget(
        InheritedProvider<int>(
          update: (_, last) {
            lastValue = last;
            return 24;
          },
          child: Context(),
        ),
      );

      expect(of<int>(), equals(24));
      expect(lastValue, equals(42));
    });
    test('throws if both builder and initialBuilder are missing', () {
      expect(
        () => InheritedProvider<int>(child: Container()),
        throwsAssertionError,
      );
    });
    testWidgets('calls initialValueBuilder lazily once', (tester) async {
      final initialValueBuilder = InitialValueBuilderMock<int>();
      when(initialValueBuilder(any)).thenReturn(42);

      await tester.pumpWidget(
        InheritedProvider<int>(
          create: initialValueBuilder,
          child: Context(),
        ),
      );

      verifyZeroInteractions(initialValueBuilder);

      final inheritedProviderElement = tester.element(
        find.byWidgetPredicate((w) => w is InheritedProvider<int>),
      );

      expect(of<int>(), equals(42));
      verify(initialValueBuilder(inheritedProviderElement)).called(1);

      await tester.pumpWidget(
        InheritedProvider<int>(
          create: initialValueBuilder,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(42));
      verifyNoMoreInteractions(initialValueBuilder);
    });
  });

  group('DeferredInheritedProvider.value()', () {
    // TODO: stopListening cannot be null
    testWidgets('startListening', (tester) async {
      final stopListening = StopListeningMock();
      final startListening =
          DeferredStartListeningMock<ValueNotifier<int>, int>(
        (e, setState, controller, value) {
          setState(controller.value);
          return stopListening;
        },
      );
      final controller = ValueNotifier<int>(0);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller,
          startListening: startListening,
          child: Context(),
        ),
      );

      verifyZeroInteractions(startListening);

      expect(of<int>(), equals(0));

      verify(startListening(
        argThat(isNotNull),
        argThat(isNotNull),
        controller,
        null,
      )).called(1);

      expect(of<int>(), equals(0));
      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller,
          startListening: startListening,
          child: Context(),
        ),
      );

      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);

      await tester.pumpWidget(Container());

      verifyNoMoreInteractions(startListening);
      verify(stopListening()).called(1);
    });

    testWidgets('stopListening cannot be null', (tester) async {
      final controller = ValueNotifier<int>(0);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller,
          startListening: (_, setState, __, ___) {
            setState(0);
            return () {};
          },
          child: const TextOf<int>(),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      final controller2 = ValueNotifier<int>(0);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller2,
          startListening: (_, setState, __, ___) => null,
          child: const TextOf<int>(),
        ),
      );

      expect(tester.takeException(), isAssertionError);
    });
    testWidgets("startListening doesn't need setState if already initialized",
        (tester) async {
      final startListening =
          DeferredStartListeningMock<ValueNotifier<int>, int>(
        (e, setState, controller, value) {
          setState(controller.value);
          return () {};
        },
      );
      final controller = ValueNotifier<int>(0);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller,
          startListening: startListening,
          child: const TextOf<int>(),
        ),
      );

      expect(find.text('0'), findsOneWidget);

      final startListening2 =
          DeferredStartListeningMock<ValueNotifier<int>, int>();
      when(startListening2(any, any, any, any)).thenReturn(() {});
      final controller2 = ValueNotifier<int>(0);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller2,
          startListening: startListening2,
          child: const TextOf<int>(),
        ),
      );

      expect(
        find.text('0'),
        findsOneWidget,
        reason: 'startListening2 did not call setState but startListening did',
      );
    });
    testWidgets('setState without updateShouldNotify', (tester) async {
      void Function(int value) setState;
      var buildCount = 0;

      await tester.pumpWidget(
        DeferredInheritedProvider<int, int>.value(
          value: 0,
          startListening: (_, s, __, ___) {
            setState = s;
            setState(0);
            return () {};
          },
          child: Consumer<int>(
            builder: (_, value, __) {
              buildCount++;
              return Text('$value', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(buildCount, equals(1));

      setState(0);
      await tester.pump();

      expect(buildCount, equals(1));
      expect(find.text('0'), findsOneWidget);

      setState(1);
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(buildCount, equals(2));

      setState(1);
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(buildCount, equals(2));
    });
    testWidgets('setState with updateShouldNotify', (tester) async {
      final updateShouldNotify = UpdateShouldNotifyMock<int>();
      when(updateShouldNotify(any, any)).thenAnswer((i) {
        return i.positionalArguments[0] != i.positionalArguments[1];
      });
      void Function(int value) setState;
      var buildCount = 0;

      await tester.pumpWidget(
        DeferredInheritedProvider<int, int>.value(
          value: 0,
          updateShouldNotify: updateShouldNotify,
          startListening: (_, s, __, ___) {
            setState = s;
            setState(0);
            return () {};
          },
          child: Consumer<int>(
            builder: (_, value, __) {
              buildCount++;
              return Text('$value', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(buildCount, equals(1));
      verifyZeroInteractions(updateShouldNotify);

      setState(0);
      await tester.pump();

      verify(updateShouldNotify(0, 0)).called(1);
      verifyNoMoreInteractions(updateShouldNotify);
      expect(buildCount, equals(1));
      expect(find.text('0'), findsOneWidget);

      setState(1);
      await tester.pump();

      verify(updateShouldNotify(0, 1)).called(1);
      verifyNoMoreInteractions(updateShouldNotify);
      expect(find.text('1'), findsOneWidget);
      expect(buildCount, equals(2));

      setState(1);
      await tester.pump();

      verify(updateShouldNotify(1, 1)).called(1);
      verifyNoMoreInteractions(updateShouldNotify);
      expect(find.text('1'), findsOneWidget);
      expect(buildCount, equals(2));
    });
    testWidgets('startListening never leave the widget uninitialized',
        (tester) async {
      final startListening =
          DeferredStartListeningMock<ValueNotifier<int>, int>();
      when(startListening(any, any, any, any)).thenReturn(() {});
      final controller = ValueNotifier<int>(0);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller,
          startListening: startListening,
          child: const TextOf<int>(),
        ),
      );

      expect(
        tester.takeException(),
        isAssertionError,
        reason: 'startListening did not call setState',
      );
    });

    testWidgets('startListening called again on controller change',
        (tester) async {
      var buildCount = 0;
      final child = Consumer<int>(builder: (_, value, __) {
        buildCount++;
        return Text('$value', textDirection: TextDirection.ltr);
      });

      final stopListening = StopListeningMock();
      final startListening =
          DeferredStartListeningMock<ValueNotifier<int>, int>(
        (e, setState, controller, value) {
          setState(controller.value);
          return stopListening;
        },
      );
      final controller = ValueNotifier<int>(0);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller,
          startListening: startListening,
          child: child,
        ),
      );

      expect(buildCount, equals(1));
      expect(find.text('0'), findsOneWidget);
      verify(startListening(any, any, controller, null)).called(1);
      verifyZeroInteractions(stopListening);

      final stopListening2 = StopListeningMock();
      final startListening2 =
          DeferredStartListeningMock<ValueNotifier<int>, int>(
        (e, setState, controller, value) {
          setState(controller.value);
          return stopListening2;
        },
      );
      final controller2 = ValueNotifier<int>(1);

      await tester.pumpWidget(
        DeferredInheritedProvider<ValueNotifier<int>, int>.value(
          value: controller2,
          startListening: startListening2,
          child: child,
        ),
      );

      expect(buildCount, equals(2));
      expect(find.text('1'), findsOneWidget);
      verifyInOrder([
        stopListening(),
        startListening2(argThat(isNotNull), argThat(isNotNull), controller2, 0),
      ]);
      verifyNoMoreInteractions(startListening);
      verifyNoMoreInteractions(stopListening);
      verifyZeroInteractions(stopListening2);

      await tester.pumpWidget(Container());

      verifyNoMoreInteractions(startListening);
      verifyNoMoreInteractions(stopListening);
      verifyNoMoreInteractions(startListening2);
      verify(stopListening2()).called(1);
    });
  });
  group('DeferredInheritedProvider()', () {
    testWidgets("create can't call inherited widgets", (tester) async {
      await tester.pumpWidget(
        InheritedProvider<String>.value(
          value: 'hello',
          child: DeferredInheritedProvider<int, int>(
            create: (context) {
              Provider.of<String>(context);
              return 42;
            },
            startListening: (_, setState, ___, ____) {
              setState(0);
              return () {};
            },
            child: const TextOf<int>(),
          ),
        ),
      );

      expect(tester.takeException(), isFlutterError);
    });
    testWidgets('creates the value lazily', (tester) async {
      final create = InitialValueBuilderMock<String>('0');
      final stopListening = StopListeningMock();
      final startListening = DeferredStartListeningMock<String, int>(
        (_, setState, __, ___) {
          setState(0);
          return stopListening;
        },
      );

      await tester.pumpWidget(
        DeferredInheritedProvider<String, int>(
          create: create,
          startListening: startListening,
          child: Context(),
        ),
      );

      verifyZeroInteractions(create);
      verifyZeroInteractions(startListening);
      verifyZeroInteractions(stopListening);

      expect(of<int>(), equals(0));

      verify(create(argThat(isNotNull))).called(1);
      verify(startListening(argThat(isNotNull), argThat(isNotNull), '0', null))
          .called(1);

      expect(of<int>(), equals(0));

      verifyNoMoreInteractions(create);
      verifyNoMoreInteractions(startListening);
      verifyZeroInteractions(stopListening);
    });
    testWidgets('dispose', (tester) async {
      final dispose = DisposeMock<String>();
      final stopListening = StopListeningMock();

      await tester.pumpWidget(
        DeferredInheritedProvider<String, int>(
          create: (_) => '42',
          startListening: (_, setState, __, ___) {
            setState(0);
            return stopListening;
          },
          dispose: dispose,
          child: Context(),
        ),
      );

      expect(of<int>(), equals(0));

      verifyZeroInteractions(dispose);

      await tester.pumpWidget(Container());

      verifyInOrder([
        stopListening(),
        dispose(argThat(isNotNull), '42'),
      ]);
      verifyNoMoreInteractions(dispose);
    });
    testWidgets('dispose no-op if never built', (tester) async {
      final dispose = DisposeMock<String>();

      await tester.pumpWidget(
        DeferredInheritedProvider<String, int>(
          create: (_) => '42',
          startListening: (_, setState, __, ___) {
            setState(0);
            return () {};
          },
          dispose: dispose,
          child: Context(),
        ),
      );

      verifyZeroInteractions(dispose);

      await tester.pumpWidget(Container());

      verifyZeroInteractions(dispose);
    });
  });

  testWidgets('startListening markNeedsNotifyDependents', (tester) async {
    InheritedProviderElement<int> element;
    var buildCount = 0;

    await tester.pumpWidget(
      InheritedProvider<int>(
        update: (_, __) => 24,
        startListening: (e, value) {
          element = e;
          return () {};
        },
        child: Consumer<int>(
          builder: (_, __, ___) {
            buildCount++;
            return Container();
          },
        ),
      ),
    );

    expect(buildCount, equals(1));

    element.markNeedsNotifyDependents();
    await tester.pump();

    expect(buildCount, equals(2));

    await tester.pump();

    expect(buildCount, equals(2));
  });

  testWidgets('InheritedProvider can be subclassed', (tester) async {
    await tester.pumpWidget(
      SubclassProvider(
        key: UniqueKey(),
        value: 42,
        child: Context(),
      ),
    );

    expect(of<int>(), equals(42));

    await tester.pumpWidget(
      SubclassProvider.value(
        key: UniqueKey(),
        value: 24,
        child: Context(),
      ),
    );

    expect(of<int>(), equals(24));
  });
  testWidgets('DeferredInheritedProvider can be subclassed', (tester) async {
    await tester.pumpWidget(
      DeferredSubclassProvider(
        key: UniqueKey(),
        value: 42,
        child: Context(),
      ),
    );

    expect(of<int>(), equals(42));

    await tester.pumpWidget(
      DeferredSubclassProvider.value(
        key: UniqueKey(),
        value: 24,
        child: Context(),
      ),
    );

    expect(of<int>(), equals(24));
  });

  testWidgets('can be used with MultiProvider', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider.value(value: 42),
        ],
        child: Context(),
      ),
    );

    expect(of<int>(), equals(42));
  });

  testWidgets('throw if the widget ctor changes', (tester) async {
    await tester.pumpWidget(
      InheritedProvider<int>(
        update: (_, __) => 42,
        child: Container(),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      InheritedProvider<int>.value(
        value: 42,
        child: Container(),
      ),
    );

    expect(tester.takeException(), isStateError);
  });

  testWidgets('InheritedProvider lazy loading can be disabled', (tester) async {
    final startListening = StartListeningMock<int>(() {});

    await tester.pumpWidget(
      InheritedProvider(
        key: UniqueKey(),
        create: (_) => 42,
        startListening: startListening,
        lazy: false,
        child: Container(),
      ),
    );
    verify(startListening(argThat(isNotNull), 42)).called(1);
  });

  testWidgets('InheritedProvider.value lazy loading can be disabled',
      (tester) async {
    final startListening = StartListeningMock<int>(() {});

    await tester.pumpWidget(
      InheritedProvider.value(
        key: UniqueKey(),
        value: 42,
        startListening: startListening,
        lazy: false,
        child: Container(),
      ),
    );

    verify(startListening(argThat(isNotNull), 42)).called(1);
    verifyNoMoreInteractions(startListening);
  });
  testWidgets('DeferredInheritedProvider lazy loading can be disabled',
      (tester) async {
    final startListening =
        DeferredStartListeningMock<int, int>((a, setState, c, d) {
      setState(0);
      return () {};
    });

    await tester.pumpWidget(
      DeferredInheritedProvider<int, int>(
        key: UniqueKey(),
        create: (_) => 42,
        startListening: startListening,
        lazy: false,
        child: Container(),
      ),
    );

    verify(startListening(argThat(isNotNull), argThat(isNotNull), 42, null))
        .called(1);
    verifyNoMoreInteractions(startListening);
  });
  testWidgets('DeferredInheritedProvider.value lazy loading can be disabled',
      (tester) async {
    final startListening =
        DeferredStartListeningMock<int, int>((a, setState, c, d) {
      setState(0);
      return () {};
    });

    await tester.pumpWidget(
      DeferredInheritedProvider<int, int>.value(
        key: UniqueKey(),
        value: 42,
        startListening: startListening,
        lazy: false,
        child: Container(),
      ),
    );

    verify(startListening(argThat(isNotNull), argThat(isNotNull), 42, null))
        .called(1);
    verifyNoMoreInteractions(startListening);
  });
}

class SubclassProvider extends InheritedProvider<int> {
  SubclassProvider({Key key, int value, Widget child})
      : super(key: key, create: (_) => value, child: child);

  SubclassProvider.value({Key key, int value, Widget child})
      : super.value(key: key, value: value, child: child);
}

class DeferredSubclassProvider extends DeferredInheritedProvider<int, int> {
  DeferredSubclassProvider({Key key, int value, Widget child})
      : super(
          key: key,
          create: (_) => value,
          startListening: (_, setState, ___, ____) {
            setState(value);
            return () {};
          },
          child: child,
        );

  DeferredSubclassProvider.value({Key key, int value, Widget child})
      : super.value(
          key: key,
          value: value,
          startListening: (_, setState, ___, ____) {
            setState(value);
            return () {};
          },
          child: child,
        );
}
