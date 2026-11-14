import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_icons.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../models/production_snapshot.dart';
import 'production_dashboard.dart';
import 'production_widgets.dart';

/// Mirrors the web Production dashboard: totals, house space and a filterable timeline.
class ProductionOverviewTab extends StatefulWidget {
    final ProductionSnapshot data;
    final Future<void> Function() onChanged;
    final bool canManage;

    const ProductionOverviewTab(
        {super.key, required this.data, required this.onChanged, required this.canManage});

    @override
    State<ProductionOverviewTab> createState() => _ProductionOverviewTabState();
}

class _ProductionOverviewTabState extends State<ProductionOverviewTab> {
    TimelineKind? _kind;
    String? _equipmentId;
    DateTime? _from;
    DateTime? _to;

    DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

    List<TimelineEvent> _events() => buildTimeline(widget.data).where((e) {
        final d = _day(e.date);
        return (_kind == null || e.kind == _kind) &&
            (_from == null || !d.isBefore(_day(_from!))) &&
            (_to == null || !d.isAfter(_day(_to!))) &&
            (_equipmentId == null || e.equipmentId == _equipmentId);
    }).toList();

    @override
    Widget build(BuildContext context) {
        final t = buildTotals(widget.data);
        final events = _events();
        final cards = <_Kpi>[
            _Kpi(Icons.egg_alt_outlined, 'Active batches', '${t.activeBatches}', AppColors.warning),
            _Kpi(AppIcons.incubate, 'Eggs incubating', '${t.eggsIncubating}', AppColors.warning),
            _Kpi(Icons.egg_outlined, 'Eggs in hatcher', '${t.eggsInHatcher}', AppColors.info),
            _Kpi(Icons.inventory_2_outlined, 'Eggs not yet assigned', '${t.eggsUnassigned}',
                AppColors.secondaryDark),
            _Kpi(AppIcons.house, 'Birds in houses', '${t.birdsInHouses} / ${t.houseCapacity}',
                AppColors.info),
            _Kpi(Icons.heart_broken_outlined, 'Mortality', '${t.mortality}', AppColors.error),
            _Kpi(Icons.payments_outlined, 'Sold', '${t.sold}', AppColors.secondaryDark),
            _Kpi(Icons.checklist, 'Open tasks', '${t.openTasks}',
                t.overdueTasks > 0 ? AppColors.error : AppColors.warning,
                note: t.overdueTasks > 0 ? '${t.overdueTasks} overdue' : null),
            _Kpi(Icons.event_note_outlined, 'Plans to review', '${t.plansNeedingReview}',
                AppColors.secondaryDark),
        ];
        return RefreshIndicator(
            onRefresh: widget.onChanged,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                    const SectionTitle('Production dashboard',
                        info: 'A summary of the whole production cycle: eggs in incubators and hatchers, birds in chicken houses, open tasks and plans to review. The timeline lists transfers, hatch dates and placements; forecast dates are planned, not yet done.'),
                    Text('Eggs, birds and what is coming up.',
                        style: TextStyle(color: AppColors.textSecondary(context))),
                    const SizedBox(height: 12),
                    LayoutBuilder(builder: (context, c) {
                        final width = (c.maxWidth - 16) / 3;
                        return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: cards.map((k) => SizedBox(width: width, child: k)).toList(),
                        );
                    }),
                    const SizedBox(height: 16),
                    _capacity(context, t),
                    const SizedBox(height: 8),
                    Text(
                        'Totals come from your batches, houses and movements. Dates marked "forecast" are planned, not yet done.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                    const SectionTitle('Timeline'),
                    const SizedBox(height: 4),
                    _filters(context),
                    const SizedBox(height: 4),
                    if (events.isEmpty)
                        const EmptyState(
                            icon: Icons.event_outlined, message: 'No events match these filters.')
                    else
                        ...events.map((e) => _EventTile(event: e)),
                ],
            ),
        );
    }

    Widget _capacity(BuildContext context, DashboardTotals t) {
        final ratio = t.usedPercent / 100;
        final color = t.usedPercent >= 90 ? AppColors.error : AppColors.success;
        return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Chicken house space',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${t.birdsInHouses} of ${t.houseCapacity} birds (${t.usedPercent}% full)',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
                const SizedBox(height: 10),
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                    ),
                ),
            ]),
        );
    }

    Widget _filters(BuildContext context) {
        final dense = InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            labelStyle: const TextStyle(fontSize: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        );
        Widget dropdown<T>(String label, T? value, List<DropdownMenuItem<T?>> items,
                ValueChanged<T?> onChanged) =>
            Expanded(
                child: DropdownButtonFormField<T?>(
                    value: value,
                    items: items,
                    onChanged: onChanged,
                    isExpanded: true,
                    style: TextStyle(fontSize: 12, color: AppColors.textPrimary(context)),
                    iconSize: 18,
                    decoration: dense.copyWith(labelText: label),
                ),
            );
        return Column(children: [
            Row(children: [
                dropdown<TimelineKind>('Show', _kind, [
                    const DropdownMenuItem(value: null, child: Text('Everything')),
                    ...TimelineKind.values.map(
                        (k) => DropdownMenuItem(value: k, child: Text(timelineKindLabel(k)))),
                ], (v) => setState(() => _kind = v)),
                const SizedBox(width: 8),
                dropdown<String>('Equipment', _equipmentId, [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...widget.data.equipment
                        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))),
                ], (v) => setState(() => _equipmentId = v)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
                Expanded(
                    child: _OptionalDate(
                        label: 'From', value: _from, onChanged: (d) => setState(() => _from = d))),
                const SizedBox(width: 8),
                Expanded(
                    child: _OptionalDate(
                        label: 'To', value: _to, onChanged: (d) => setState(() => _to = d))),
            ]),
        ]);
    }
}

class _OptionalDate extends StatelessWidget {
    final String label;
    final DateTime? value;
    final ValueChanged<DateTime?> onChanged;

    const _OptionalDate(
        {required this.label, required this.value, required this.onChanged});

    @override
    Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 3));
            if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
            decoration: InputDecoration(
                labelText: label,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                labelStyle: const TextStyle(fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: value == null
                    ? const Icon(Icons.calendar_today_outlined, size: 14)
                    : InkWell(
                        onTap: () => onChanged(null),
                        child: const Icon(Icons.close, size: 16)),
                suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            child: Text(value == null ? ' ' : formatDate(value),
                style: const TextStyle(fontSize: 12)),
        ),
    );
}

class _EventTile extends StatelessWidget {
    final TimelineEvent event;

    const _EventTile({required this.event});

    Color _color() => switch (event.kind) {
            TimelineKind.transfer => AppColors.info,
            TimelineKind.hatch => AppColors.warning,
            TimelineKind.placement => AppColors.success,
            TimelineKind.task => AppColors.error,
            TimelineKind.saleReady => AppColors.secondaryDark,
        };

    @override
    Widget build(BuildContext context) {
        final color = _color();
        return Opacity(
            opacity: event.forecast ? 0.85 : 1,
            child: SectionCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                        Text(formatDate(event.date),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        StatusChip(timelineKindLabel(event.kind), color),
                    ]),
                    const SizedBox(height: 4),
                    Text(event.title),
                    const SizedBox(height: 2),
                    Text('${event.forecast ? 'Forecast' : 'Actual'} · ${event.detail}',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                ]),
            ),
        );
    }
}

class _Kpi extends StatelessWidget {
    final IconData icon;
    final String title;
    final String value;
    final Color color;
    final String? note;

    const _Kpi(this.icon, this.title, this.value, this.color, {this.note});

    @override
    Widget build(BuildContext context) => Card(
        elevation: 1.5,
        margin: EdgeInsets.zero,
        shadowColor: color.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: AppColors.surface(context),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(height: 8),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, height: 1.2, color: AppColors.textSecondary(context))),
                if (note != null)
                    Text(note!, style: TextStyle(fontSize: 10, color: color)),
            ]),
        ),
    );
}
