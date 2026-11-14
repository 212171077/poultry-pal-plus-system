import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poultry_pal_plus_app/models/production_plan.dart';
import 'package:poultry_pal_plus_app/models/production_settings.dart';
import 'package:poultry_pal_plus_app/models/production_snapshot.dart';
import 'package:poultry_pal_plus_app/screens/production/production_plans_tab.dart';
import 'package:poultry_pal_plus_app/theme/app_icons.dart';

ProductionSnapshot snapshot({bool ownEggs = true, bool review = false}) {
  final date = DateTime(2026, 11, 24);
  final calculation = PlanCalculation(
    ownEggs: ownEggs,
    targetReadyDate: date,
    targetQuantity: 100,
    targetAgeDays: 42,
    housePlacementDate: date,
    hatchOrArrivalDate: date,
    incubationStartDate: ownEggs ? date : null,
    transferDate: ownEggs ? date : null,
    latestOrderDate: ownEggs ? null : date,
    eggsRequired: ownEggs ? 130 : null,
    chicksRequired: 110,
    feasible: true,
    constraints: const [],
    assumptions: const [],
  );
  return ProductionSnapshot(
    generatedAt: date,
    settings: const ProductionSettings(
      id: 'settings',
      timeZone: 'Africa/Johannesburg',
      incubationDays: 21,
      transferDay: 18,
      broodingDays: 14,
      expectedHatchRate: 0.8,
      expectedMortalityRate: 0.05,
      defaultGrowOutDays: 42,
      supplierLeadTimeDays: 7,
      estimatesOnly: true,
      version: 0,
    ),
    equipment: const [],
    batches: const [],
    reminders: const [],
    placements: const [],
    occupancy: const [],
    plans: [
      ProductionPlan(
        id: 'plan',
        name: 'Batch',
        status: review ? PlanStatus.needsReview : PlanStatus.draft,
        calculation: calculation,
        recalculation: review ? calculation : null,
        version: 0,
      ),
    ],
  );
}

void main() {
  for (final width in [320.0, 360.0, 412.0, 800.0]) {
    for (final ownEggs in [true, false]) {
      for (final textScale in [1.0, 1.5]) {
        testWidgets(
            'three columns at $width, own eggs: $ownEggs, scale: $textScale',
            (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 1800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(textScale),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: ProductionPlansTab(
                data: snapshot(ownEggs: ownEggs),
                canManage: false,
                onChanged: () async {},
              ),
            ),
          ));
          await tester.pumpAndSettle();
          final labels = ownEggs
              ? [
                  'Start incubating',
                  'Transfer',
                  'Hatch',
                  'Into house',
                  'Ready',
                  'Eggs needed',
                  'Chicks needed'
                ]
              : [
                  'Order by',
                  'Chicks arrive',
                  'Into house',
                  'Ready',
                  'Chicks needed'
                ];
          final rects = [
            for (final label in labels)
              tester.getRect(find.byKey(ValueKey('plan-milestone-$label'))),
          ];
          for (var i = 0; i < rects.length; i++) {
            expect(rects[i].width, closeTo(rects.first.width, 0.01));
            expect(find.text(labels[i]), findsOneWidget);
            if (i % 3 != 0) {
              expect(rects[i].top, rects[i - 1].top);
              expect(rects[i].left - rects[i - 1].right, closeTo(6, 0.01));
            } else if (i > 0) {
              expect(rects[i].top - rects[i - 3].bottom, closeTo(6, 0.01));
            }
          }
          expect(find.byIcon(ownEggs ? AppIcons.hatch : AppIcons.chick),
              ownEggs ? findsOneWidget : findsNWidgets(2));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('review calculations retain the same three-column layout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProductionPlansTab(
          data: snapshot(review: true),
          canManage: false,
          onChanged: () async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Suggested new dates'), findsOneWidget);
    expect(find.byIcon(AppIcons.hatch), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('bundled poultry font contains three distinct glyphs',
      (tester) async {
    final font = await rootBundle.load('assets/icons/poultry_icons.ttf');
    expect(font.lengthInBytes, greaterThan(0));
    expect({AppIcons.chicken, AppIcons.chick, AppIcons.hatch}.length, 3);
    for (final icon in [AppIcons.chicken, AppIcons.chick, AppIcons.hatch]) {
      expect(icon.fontFamily, 'PoultryIcons');
    }
  });
}
