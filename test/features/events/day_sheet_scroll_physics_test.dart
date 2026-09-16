import 'package:daily/features/events/presentation/day_sheet_scroll_physics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FixedScrollMetrics metrics(double maximum) => FixedScrollMetrics(
    minScrollExtent: 0,
    maxScrollExtent: maximum,
    pixels: 0,
    viewportDimension: 300,
    axisDirection: AxisDirection.down,
    devicePixelRatio: 1,
  );

  test('collapsed stage blocks list movement with any event count', () {
    final physics = DaySheetScrollPhysics(isCollapsed: () => true);
    for (final overflow in [0.0, 20.0, 500.0]) {
      expect(physics.applyBoundaryConditions(metrics(overflow), 20), 20);
      expect(physics.applyBoundaryConditions(metrics(overflow), -20), -20);
      expect(physics.shouldAcceptUserOffset(metrics(overflow)), isTrue);
    }
  });

  test('other stages use their own current overflow and never bounce', () {
    final physics = DaySheetScrollPhysics(isCollapsed: () => false);
    // The same list overflows a medium viewport but fits an expanded viewport.
    expect(physics.applyBoundaryConditions(metrics(80), 40), 0);
    expect(physics.applyBoundaryConditions(metrics(80), 100), 20);
    expect(physics.applyBoundaryConditions(metrics(0), 40), 40);
    expect(physics.applyBoundaryConditions(metrics(0), -40), -40);
  });

  for (final count in [0, 1, 10]) {
    testWidgets(
      '$count events keep collapsed offset at zero and allow expansion',
      (tester) async {
        final sheet = DraggableScrollableController();
        addTearDown(sheet.dispose);
        ScrollController? list;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DraggableScrollableSheet(
                controller: sheet,
                initialChildSize: .4,
                minChildSize: .4,
                maxChildSize: .96,
                builder: (context, controller) {
                  list = controller;
                  return ListenableBuilder(
                    listenable: sheet,
                    builder: (context, _) => ListView(
                      controller: controller,
                      physics: DaySheetScrollPhysics(
                        isCollapsed: () =>
                            !sheet.isAttached || sheet.size <= .4001,
                      ),
                      children: [
                        const SizedBox(height: 80),
                        for (var i = 0; i < count; i++)
                          const SizedBox(height: 90),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, 80));
        await tester.pumpAndSettle();
        expect(list!.offset, 0);
        await tester.drag(find.byType(ListView), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(sheet.size, greaterThan(.4));
        sheet.jumpTo(.96);
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(list!.offset, count == 10 ? greaterThan(0) : 0);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
