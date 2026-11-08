import 'package:daily/features/events/presentation/day_sheet_drag_release.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  double? target(double start, double end, double velocity) =>
      daySheetReleaseTarget(
        startSize: start,
        endSize: end,
        downwardVelocity: velocity,
        smallestStage: .4,
      );

  test('short slow drags keep stage snapping at every size', () {
    // Large and medium: under one stage gap, released slowly.
    expect(target(.96, .8, .3), isNull);
    expect(target(.96, .62, 0), isNull);
    expect(target(.68, .5, .3), isNull);
    expect(target(.68, .45, 0), isNull);
    // Short travel stays a stage step even when fast.
    expect(target(.96, .93, 3), isNull);
    expect(target(.68, .65, 3), isNull);
    // Medium-speed drags need some distance before they close.
    expect(target(.96, .8, .9), isNull);
    expect(target(.68, .52, .9), isNull);
  });

  test('flings close from every size', () {
    expect(target(.96, .9, 1), 0);
    expect(target(.68, .62, 1.2), 0);
    expect(target(.4, .35, 1), 0);
  });

  test('medium-speed drags of a fifth of the height close', () {
    expect(target(.96, .75, .5), 0);
    expect(target(.68, .47, .6), 0);
  });

  test('slow drags clearly past the next stage close', () {
    expect(target(.96, .6, 0), 0);
    expect(target(.68, .32, 0), 0);
  });

  test('small stage follows down and closes or returns', () {
    expect(target(.4, .32, 0), 0);
    expect(target(.4, .36, .6), 0);
    expect(target(.4, .36, .2), .4);
    expect(target(.68, .36, 0), .4);
  });

  test('upward releases are left to the sheet', () {
    expect(target(.4, .3, -1), isNull);
    expect(target(.96, .3, -1), isNull);
  });

  Future<(DraggableScrollableController, PersistentBottomSheetController)>
  openSheet(WidgetTester tester, double initialSize) async {
    final sheet = DraggableScrollableController();
    addTearDown(sheet.dispose);
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(key: scaffoldKey, body: const SizedBox.expand()),
      ),
    );
    final controller = scaffoldKey.currentState!.showBottomSheet(
      (_) => DaySheetDragDismissListener(
        controller: sheet,
        smallestStage: .4,
        child: DraggableScrollableSheet(
          controller: sheet,
          expand: false,
          initialChildSize: initialSize,
          minChildSize: 0,
          maxChildSize: .96,
          snap: true,
          snapSizes: const [.4, .68],
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            children: [
              for (var i = 0; i < 30; i++)
                SizedBox(height: 60, child: Text('$i')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (sheet, controller);
  }

  Future<void> slowDrag(WidgetTester tester, double dy) async {
    final gesture = await tester.startGesture(
      tester.getTopLeft(find.byType(ListView)) + const Offset(20, 20),
    );
    const steps = 20;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, dy / steps));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('one long drag from large closes the sheet', (tester) async {
    final (_, controller) = await openSheet(tester, .96);
    var closed = false;
    controller.closed.then((_) => closed = true);
    final height = tester.getSize(find.byType(Scaffold)).height;
    await slowDrag(tester, height * .5);
    expect(closed, isTrue);
  });

  testWidgets('short slow drag from large steps down to medium', (
    tester,
  ) async {
    final (sheet, _) = await openSheet(tester, .96);
    final height = tester.getSize(find.byType(Scaffold)).height;
    await slowDrag(tester, height * .25);
    expect(sheet.size, closeTo(.68, .01));
  });

  for (final initialSize in [.96, .68]) {
    testWidgets('short fling from $initialSize closes the sheet', (
      tester,
    ) async {
      final (_, controller) = await openSheet(tester, initialSize);
      var closed = false;
      controller.closed.then((_) => closed = true);
      final height = tester.getSize(find.byType(Scaffold)).height;
      await tester.fling(find.byType(ListView), Offset(0, height * .12), 1000);
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  }

  // iOS delivers the touch end one frame after the last move at the same
  // position; that stationary sample must not halve the release velocity.
  testWidgets(
    'flick released one frame later still closes',
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
    (tester) async {
      final (_, controller) = await openSheet(tester, .68);
      var closed = false;
      controller.closed.then((_) => closed = true);
      final height = tester.getSize(find.byType(Scaffold)).height;
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(ListView)) + const Offset(20, 20),
      );
      // About 0.14 of the height in 64 ms; the up event follows 16 ms after
      // the last move without moving.
      const steps = 8;
      var time = Duration.zero;
      for (var i = 0; i < steps; i++) {
        time += const Duration(milliseconds: 8);
        await gesture.moveBy(Offset(0, height * .14 / steps), timeStamp: time);
        await tester.pump(const Duration(milliseconds: 8));
      }
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up(timeStamp: time + const Duration(milliseconds: 16));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    },
  );

  testWidgets('drag that first scrolls the list closes only from the top', (
    tester,
  ) async {
    final (sheet, controller) = await openSheet(tester, .96);
    var closed = false;
    controller.closed.then((_) => closed = true);
    final height = tester.getSize(find.byType(Scaffold)).height;
    final list = find.byType(Scrollable).first;
    final listPosition = tester.state<ScrollableState>(list).position;

    listPosition.jumpTo(height * .3);
    await tester.pump();
    // Only a little sheet travel after reaching the top: snaps back.
    await slowDrag(tester, height * .35);
    expect(listPosition.pixels, 0);
    expect(closed, isFalse);
    expect(sheet.size, closeTo(.96, .01));

    listPosition.jumpTo(height * .1);
    await tester.pump();
    // The rest of the drag after the list reaches the top closes it.
    await slowDrag(tester, height * .6);
    expect(closed, isTrue);
  });

  testWidgets('small drag below small stage returns to small', (tester) async {
    final (sheet, _) = await openSheet(tester, .4);
    final height = tester.getSize(find.byType(Scaffold)).height;
    await slowDrag(tester, height * .05);
    expect(sheet.isAttached, isTrue);
    expect(sheet.size, closeTo(.4, .01));
  });
}
