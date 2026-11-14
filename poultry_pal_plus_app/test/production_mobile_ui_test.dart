import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_pal_plus_app/models/bird_placement.dart';
import 'package:poultry_pal_plus_app/models/hatch_result.dart';
import 'package:poultry_pal_plus_app/models/production_snapshot.dart';
import 'package:poultry_pal_plus_app/screens/production/production_hatch_tab.dart';
import 'package:poultry_pal_plus_app/screens/production/production_placements_tab.dart';
import 'package:poultry_pal_plus_app/screens/production/production_widgets.dart';

import 'production_plans_tab_test.dart' as fixtures;

ProductionSnapshot placements({bool active = true}) {
  final base = fixtures.snapshot();
  return ProductionSnapshot(
    generatedAt: base.generatedAt,
    settings: base.settings,
    equipment: const [],
    batches: const [],
    reminders: const [],
    occupancy: const [],
    plans: const [],
    placements: [
      BirdPlacement(
        id: 'placement',
        reference: 'Placement 1',
        source: PlacementSource.purchasedDayOld,
        houseId: 'house',
        quantity: 100,
        placementDate: DateTime(2026, 11, 4),
        remaining: active ? 90 : 0,
        mortality: 5,
        sold: 5,
        otherRemovals: 0,
        active: active,
        version: 0,
      ),
    ],
  );
}

void main() {
  for (final canManage in [true, false]) {
    for (final active in [true, false]) {
      testWidgets('movement visibility: manager $canManage, active $active',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: ProductionPlacementsTab(
              data: placements(active: active),
              canManage: canManage,
              onChanged: () async {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final movement =
            find.widgetWithText(FilledButton, 'Record bird movement');
        expect(movement, canManage && active ? findsOneWidget : findsNothing);
        expect(find.widgetWithText(FilledButton, 'Place chicks'),
            canManage ? findsOneWidget : findsNothing);
        if (canManage && active) {
          await tester.tap(movement);
          await tester.pumpAndSettle();
          expect(find.text('Record bird movement'), findsNWidgets(2));
          expect(find.text('Type'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('dropdown uses the same compact text style as inputs',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          DropdownInput<String>(
            label: 'Source',
            value: 'own',
            items: const [
              DropdownMenuItem(value: 'own', child: Text('Own hatch')),
            ],
            onChanged: (_) {},
          ),
          AppTextInput(label: 'Reference', controller: controller),
          NumberField(label: 'Birds', controller: controller),
        ]),
      ),
    ));
    final dropdown = tester
        .widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(dropdown.style?.fontSize, 14);
    for (final field in fields) {
      expect(field.style?.fontSize, dropdown.style?.fontSize);
    }
    await tester.tap(find.text('Own hatch').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final keyboard in [0.0, 300.0]) {
    testWidgets('sheet action clears navigation and keyboard ($keyboard)',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.devicePixelRatio = 1;
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
      tester.view.padding = FakeViewPadding(bottom: keyboard == 0 ? 48 : 0);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => showFormSheet<void>(
                      context,
                      title: 'Form',
                      builder: (_) => Column(children: [
                        for (var i = 0; i < 12; i++)
                          const SizedBox(height: 60, child: Text('Input')),
                        SubmitButton(
                            label: 'Save', busy: false, onPressed: () {}),
                      ]),
                    ),
                    child: const Text('Open'),
                  )),
        ),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Save'),
        find.byType(SingleChildScrollView).last,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      final rect = tester.getRect(find.widgetWithText(FilledButton, 'Save'));
      expect(
          rect.bottom, lessThanOrEqualTo(800 - (keyboard > 0 ? keyboard : 48)));
      expect(rect.top, greaterThan(0));
      expect(find.text('Save').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 412.0]) {
    for (final rate in [null, 80.0]) {
      testWidgets('hatch cards fit width $width with rate $rate',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 2400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final report = HatchingReport(
          summary: HatchingSummary(
              results: 1,
              eggsTransferred: 100,
              hatchedChicks: 80,
              unhatchedEggs: 20,
              weakChicks: 3,
              hatchRate: rate,
              weakRate: 3.75),
          trend: [
            HatchingTrendPoint(
                period: 'November 2026',
                eggsTransferred: 100,
                hatchedChicks: 80,
                hatchRate: rate),
          ],
          rows: [
            HatchResult(
                id: 'result',
                hatcherCycleId: 'cycle',
                incubationBatchId: 'batch',
                batchReference: 'A long batch reference that wraps on mobile',
                cycleReference:
                    'A long hatcher cycle reference that wraps on mobile',
                eggsTransferred: 100,
                hatchedChicks: 80,
                unhatchedEggs: 20,
                weakChicks: 3,
                resultDate: DateTime(2026, 11, 4),
                hatchRate: rate,
                version: 0),
          ],
          totalElements: 1,
        );
        await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: HatchReportCards(report: report),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(DataTable), findsNothing);
        expect(find.byType(SectionCard), findsNWidgets(3));
        expect(find.text('Trend by period'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Unhatched'), findsOneWidget);
        expect(find.text('Weak chicks'), findsOneWidget);
        expect(find.text('Hatch rate: ${rate == null ? 'n/a' : '80.0%'}'),
            findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
