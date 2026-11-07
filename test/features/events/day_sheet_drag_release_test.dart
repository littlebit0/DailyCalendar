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

  test('short downward drags keep stage snapping', () {
    expect(target(.96, .8, .5), isNull);
    expect(target(.68, .5, .5), isNull);
    expect(target(.96, .6, 0), isNull);
    expect(target(.68, .45, 0), isNull);
  });

  test('long or fast drags from large and medium close', () {
    expect(target(.96, .55, 0), 0);
    expect(target(.96, .65, 2.5), 0);
    expect(target(.68, .27, 0), 0);
  });

  test('small stage follows down and closes or returns', () {
    expect(target(.4, .25, 0), 0);
    expect(target(.4, .34, 1.5), 0);
    expect(target(.4, .34, .2), .4);
    expect(target(.68, .3, 0), .4);
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

  testWidgets('short drag from large steps down to medium', (tester) async {
    final (sheet, _) = await openSheet(tester, .96);
    final height = tester.getSize(find.byType(Scaffold)).height;
    await tester.fling(find.byType(ListView), Offset(0, height * .1), 800);
    await tester.pumpAndSettle();
    expect(sheet.size, closeTo(.68, .01));
  });

  testWidgets('small drag below small stage returns to small', (tester) async {
    final (sheet, _) = await openSheet(tester, .4);
    final height = tester.getSize(find.byType(Scaffold)).height;
    await slowDrag(tester, height * .05);
    expect(sheet.isAttached, isTrue);
    expect(sheet.size, closeTo(.4, .01));
  });
}
