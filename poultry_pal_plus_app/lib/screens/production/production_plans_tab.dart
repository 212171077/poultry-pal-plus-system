import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_icons.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../models/production_plan.dart';
import '../../models/production_settings.dart';
import '../../models/production_snapshot.dart';
import '../../models/schedule_options.dart';
import '../../service/production_service.dart';
import 'production_widgets.dart';

String planStatusLabel(PlanStatus s) => switch (s) {
        PlanStatus.draft => 'Draft',
        PlanStatus.committed => 'Committed',
        PlanStatus.needsReview => 'Needs review',
        PlanStatus.completed => 'Completed',
        PlanStatus.cancelled => 'Cancelled',
    };

Color planStatusColor(PlanStatus s) => switch (s) {
        PlanStatus.draft => AppColors.info,
        PlanStatus.committed => AppColors.success,
        PlanStatus.needsReview => AppColors.warning,
        PlanStatus.completed => AppColors.secondaryDark,
        PlanStatus.cancelled => AppColors.error,
    };

class ProductionPlansTab extends StatelessWidget {
    final ProductionSnapshot data;
    final Future<void> Function() onChanged;
    final bool canManage;

    const ProductionPlansTab(
        {super.key, required this.data, required this.onChanged, required this.canManage});

    Future<void> _calculate(BuildContext context) async {
        final saved = await showFormSheet<bool>(
            context,
            title: 'Calculate a plan',
            info: 'Tell us when you want birds ready and how many. We work back to when to set eggs or order chicks and check your equipment capacity. Nothing is reserved until you commit the plan.',
            builder: (_) => const _PlanForm(),
        );
        if (saved == true) await onChanged();
    }

    @override
    Widget build(BuildContext context) {
        final plans = [...data.plans]
            ..sort((a, b) =>
                a.calculation.targetReadyDate.compareTo(b.calculation.targetReadyDate));
        return RefreshIndicator(
            onRefresh: onChanged,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                    SectionTitle('Production plans',
                        info: 'A plan works backwards from the date you want birds ready to tell you when to set eggs or order chicks, and checks that the equipment and a chicken house have space. A draft reserves nothing until you commit it.',
                        trailing: canManage
                            ? IconButton.filled(
                                onPressed: () => _calculate(context),
                                icon: const Icon(Icons.calculate_outlined),
                                tooltip: 'Calculate a plan')
                            : null),
                    Text('Work back from the date you want birds ready.',
                        style: TextStyle(color: AppColors.textSecondary(context))),
                    if (plans.isEmpty)
                        const EmptyState(
                            icon: Icons.event_note_outlined,
                            message: 'No plans yet. Calculate a plan to see when to start.')
                    else
                        ...plans.map((p) =>
                            _PlanCard(plan: p, canManage: canManage, onChanged: onChanged)),
                ],
            ),
        );
    }
}

/// "Plan a batch": searches for start dates where equipment has room.
class ProductionScheduleTab extends StatelessWidget {
    final ProductionSnapshot data;
    final Future<void> Function() onChanged;

    const ProductionScheduleTab({super.key, required this.data, required this.onChanged});

    @override
    Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onChanged,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
                const SectionTitle('Plan a batch',
                    info: 'Enter how many eggs you want to set and a range of possible start dates. The server checks every day in that range against free incubator, hatcher and chicken-house space and lists the dates that fit. Nothing is reserved.'),
                Text('Find start dates where the incubator, hatcher and house have room.',
                    style: TextStyle(color: AppColors.textSecondary(context))),
                SectionCard(child: _FindStartForm(equipment: data.equipment)),
            ],
        ),
    );
}

/// Dates, quantities and warnings of a calculation.
class _CalculationView extends StatelessWidget {
    final PlanCalculation calc;

    const _CalculationView(this.calc);

    Widget _tile(BuildContext context, IconData icon, String label, String value) {
        final secondary = AppColors.textSecondary(context);
        return Container(
            key: ValueKey('plan-milestone-$label'),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: secondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(icon, size: 15, color: secondary),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                Text(label, style: TextStyle(fontSize: 10.5, color: secondary)),
            ]),
        );
    }

    @override
    Widget build(BuildContext context) {
        final color = calc.feasible ? AppColors.success : AppColors.error;
        final tiles = <Widget>[
            if (calc.incubationStartDate != null)
                _tile(context, AppIcons.incubate, 'Start incubating',
                    formatDate(calc.incubationStartDate)),
            if (calc.transferDate != null)
                _tile(context, AppIcons.transfer, 'Transfer', formatDate(calc.transferDate)),
            if (calc.latestOrderDate != null)
                _tile(context, Icons.shopping_cart_outlined, 'Order by',
                    formatDate(calc.latestOrderDate)),
            _tile(context, calc.ownEggs ? AppIcons.hatch : AppIcons.chick,
                calc.ownEggs ? 'Hatch' : 'Chicks arrive',
                formatDate(calc.hatchOrArrivalDate)),
            _tile(context, AppIcons.house, 'Into house', formatDate(calc.housePlacementDate)),
            _tile(context, Icons.flag_outlined, 'Ready', formatDate(calc.targetReadyDate)),
            if (calc.eggsRequired != null)
                _tile(context, AppIcons.eggs, 'Eggs needed', '${calc.eggsRequired}'),
            _tile(context, AppIcons.chick, 'Chicks needed', '${calc.chicksRequired}'),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                    Icon(calc.feasible ? Icons.check_circle : Icons.error, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(calc.feasible ? 'This plan fits' : 'This plan does not fit',
                            style: TextStyle(fontWeight: FontWeight.bold, color: color))),
                ]),
            ),
            const SizedBox(height: 10),
            for (var start = 0; start < tiles.length; start += 3) ...[
                if (start > 0) const SizedBox(height: 6),
                IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            for (var column = 0; column < 3; column++) ...[
                                if (column > 0) const SizedBox(width: 6),
                                Expanded(
                                    child: start + column < tiles.length
                                        ? tiles[start + column]
                                        : const SizedBox.shrink()),
                            ],
                        ],
                    ),
                ),
            ],
            if (calc.constraints.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...calc.constraints.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(child: Text(c, style: const TextStyle(fontSize: 12))),
                    ]),
                )),
            ],
            if (calc.assumptions.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...calc.assumptions.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $a',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary(context))),
                )),
            ],
        ]);
    }
}

class _PlanCard extends StatefulWidget {
    final ProductionPlan plan;
    final bool canManage;
    final Future<void> Function() onChanged;

    const _PlanCard({required this.plan, required this.canManage, required this.onChanged});

    @override
    State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
    final ProductionService _service = ProductionService();
    bool _busy = false;

    Future<void> _command(String command, String success, {String? reason}) async {
        setState(() => _busy = true);
        final ok = await runAction(
            context, () => _service.planCommand(widget.plan.id, command, reason: reason),
            success: success);
        if (ok) await widget.onChanged();
        if (mounted) setState(() => _busy = false);
    }

    Future<void> _accept() async {
        final reason = TextEditingController();
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                title: const Text('Accept new dates?'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('Your capacity changed, so the plan has new dates. Tell us why you accept them.'),
                    const SizedBox(height: 12),
                    TextField(
                        controller: reason,
                        decoration: const InputDecoration(
                            labelText: 'Reason', border: OutlineInputBorder()),
                    ),
                ]),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true), child: const Text('Accept')),
                ],
            ),
        );
        final text = reason.text.trim();
        reason.dispose();
        if (confirmed != true) return;
        if (text.isEmpty) {
            if (mounted) showError(context, 'Enter a reason to accept the new dates.');
            return;
        }
        await _command('accept-recalculation', 'New dates accepted', reason: text);
    }

    Future<void> _cancel() async {
        if (!await confirm(context, 'Cancel plan?', 'This plan will be cancelled.',
            action: 'Cancel plan')) {
            return;
        }
        await _command('cancel', 'Plan cancelled');
    }

    @override
    Widget build(BuildContext context) {
        final p = widget.plan;
        final c = p.calculation;
        final open = p.status == PlanStatus.draft ||
            p.status == PlanStatus.committed ||
            p.status == PlanStatus.needsReview;
        final accent = planStatusColor(p.status);
        return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.surface(context),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 5, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                    Expanded(
                        child: Text(
                            p.name?.isNotEmpty == true
                                ? p.name!
                                : '${c.targetQuantity} chicks · ${formatDate(c.targetReadyDate)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                    StatusChip(planStatusLabel(p.status), planStatusColor(p.status)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                    Icon(c.ownEggs ? Icons.egg_outlined : Icons.shopping_basket_outlined,
                        size: 14, color: AppColors.textSecondary(context)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(c.ownEggs ? 'Incubate own eggs' : 'Buy day-old chicks',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)))),
                ]),
                const SizedBox(height: 12),
                _CalculationView(c),
                if (p.status == PlanStatus.needsReview && p.recalculation != null) ...[
                    const Divider(height: 24),
                    const Text('Suggested new dates',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _CalculationView(p.recalculation!),
                ],
                if (widget.canManage && open) ...[
                    const SizedBox(height: 8),
                    _busy
                        ? const Center(child: CircularProgressIndicator())
                        : Wrap(spacing: 4, children: [
                            if (p.status == PlanStatus.draft)
                                IconButton.filledTonal(
                                    onPressed: c.feasible
                                        ? () => _command('commit', 'Plan committed')
                                        : null,
                                    icon: const Icon(Icons.check),
                                    tooltip: 'Commit plan'),
                            if (p.status == PlanStatus.committed)
                                IconButton.outlined(
                                    onPressed: () =>
                                        _command('recalculate', 'Plan rechecked'),
                                    icon: const Icon(Icons.refresh),
                                    tooltip: 'Recheck plan'),
                            if (p.status == PlanStatus.needsReview)
                                IconButton.filledTonal(
                                    onPressed: _accept,
                                    icon: const Icon(Icons.event_available),
                                    tooltip: 'Accept new dates'),
                            IconButton(
                                onPressed: _cancel,
                                color: AppColors.error,
                                icon: const Icon(Icons.cancel_outlined),
                                tooltip: 'Cancel plan'),
                        ]),
                ],
            ]),
                  ),
                ),
              ]),
            ),
        );
    }
}

class _PlanForm extends StatefulWidget {
    const _PlanForm();

    @override
    State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
    final ProductionService _service = ProductionService();
    final _quantity = TextEditingController();
    final _age = TextEditingController();
    final _name = TextEditingController();
    bool _ownEggs = true;
    DateTime _ready = DateTime.now().add(const Duration(days: 60));
    PlanCalculation? _result;
    bool _busy = false;

    @override
    void dispose() {
        _quantity.dispose();
        _age.dispose();
        _name.dispose();
        super.dispose();
    }

    int? get _qty => int.tryParse(_quantity.text);

    Future<void> _calculate() async {
        final qty = _qty;
        if (qty == null || qty <= 0) {
            showError(context, 'Enter how many chicks you want ready.');
            return;
        }
        setState(() => _busy = true);
        try {
            final result = await _service.calculatePlan(
                ownEggs: _ownEggs,
                ready: _ready,
                quantity: qty,
                ageDays: int.tryParse(_age.text));
            if (mounted) setState(() => _result = result);
        } catch (e) {
            if (mounted) showError(context, e);
        }
        if (mounted) setState(() => _busy = false);
    }

    Future<void> _save() async {
        final qty = _qty;
        if (qty == null) return;
        setState(() => _busy = true);
        final ok = await runAction(
            context,
            () => _service.savePlan(
                ownEggs: _ownEggs,
                ready: _ready,
                quantity: qty,
                ageDays: int.tryParse(_age.text),
                name: _name.text.trim()),
            success: 'Plan saved');
        if (!mounted) return;
        if (ok) {
            Navigator.pop(context, true);
        } else {
            setState(() => _busy = false);
        }
    }

    @override
    Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                    showSelectedIcon: true,
                    style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((st) =>
                            st.contains(WidgetState.selected)
                                ? AppColors.adaptivePrimary(context)
                                : null),
                        foregroundColor: WidgetStateProperty.resolveWith((st) =>
                            st.contains(WidgetState.selected)
                                ? Colors.white
                                : AppColors.textSecondary(context)),
                        iconColor: WidgetStateProperty.resolveWith((st) =>
                            st.contains(WidgetState.selected) ? Colors.white : null),
                        side: WidgetStatePropertyAll(
                            BorderSide(color: AppColors.adaptivePrimary(context))),
                    ),
                    segments: const [
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.egg_outlined),
                            label: Text('Own eggs')),
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.shopping_basket_outlined),
                            label: Text('Buy chicks')),
                    ],
                    selected: {_ownEggs},
                    onSelectionChanged: (s) => setState(() {
                        _ownEggs = s.first;
                        _result = null;
                    }),
                ),
            ),
            const SizedBox(height: 16),
            DatePickerField(
                label: 'Ready date',
                helper: 'When you want the chicks ready',
                value: _ready,
                onChanged: (d) => setState(() {
                    _ready = d;
                    _result = null;
                }),
            ),
            NumberField(
                label: 'Chicks wanted',
                helper: 'How many chicks you want ready on that date',
                controller: _quantity,
                onChanged: (_) => setState(() => _result = null),
            ),
            NumberField(
                label: 'Chick age at target (days, optional)',
                helper: 'Leave empty to use your default grow-out period',
                controller: _age,
                onChanged: (_) => setState(() => _result = null),
            ),
            AppTextInput(label: 'Plan name (optional)', controller: _name),
            SubmitButton(label: 'Calculate', busy: _busy, onPressed: _calculate),
            if (_result != null) ...[
                const SizedBox(height: 16),
                _CalculationView(_result!),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                        onPressed: _busy ? null : _save, child: const Text('Save as draft')),
                ),
            ],
        ],
    );
}

class _FindStartForm extends StatefulWidget {
    final List<ProductionEquipment> equipment;

    const _FindStartForm({required this.equipment});

    @override
    State<_FindStartForm> createState() => _FindStartFormState();
}

class _FindStartFormState extends State<_FindStartForm> {
    final _eggs = TextEditingController();
    DateTime _from = DateTime.now();
    DateTime _to = DateTime.now().add(const Duration(days: 30));
    ScheduleOptions? _options;
    bool _busy = false;

    @override
    void dispose() {
        _eggs.dispose();
        super.dispose();
    }

    Future<void> _search() async {
        final eggs = int.tryParse(_eggs.text);
        if (eggs == null || eggs <= 0) {
            showError(context, 'Enter how many eggs you want to set.');
            return;
        }
        if (_to.isBefore(_from)) {
            showError(context, 'The latest start must be after the earliest start.');
            return;
        }
        setState(() => _busy = true);
        try {
            final options = await ProductionService()
                .searchSchedule(eggs: eggs, earliestStart: _from, latestStart: _to);
            if (mounted) setState(() => _options = options);
        } catch (e) {
            if (mounted) showError(context, e);
        }
        if (mounted) setState(() => _busy = false);
    }

    @override
    Widget build(BuildContext context) {
        final options = _options;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NumberField(
                label: 'Eggs to set',
                helper: 'How many eggs you want to put in the incubator',
                controller: _eggs),
            DatePickerField(
                label: 'Earliest start',
                helper: 'First day you could start',
                value: _from,
                onChanged: (d) => setState(() => _from = d)),
            DatePickerField(
                label: 'Latest start',
                helper: 'Last day you could start',
                value: _to,
                onChanged: (d) => setState(() => _to = d)),
            SubmitButton(label: 'Find start dates', busy: _busy, onPressed: _search),
            if (options != null) ...[
                const SizedBox(height: 16),
                _ResultSummary(options),
                const SizedBox(height: 14),
                const Text('Each start date',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (options.candidates.isEmpty)
                    const EmptyState(
                        icon: Icons.event_busy, message: 'No dates found in that range.')
                else
                    ...options.candidates.map((c) => _CandidateTile(
                        candidate: c,
                        recommended: options.recommendedStart == c.start)),
            ],
        ]);
    }
}

class _CandidateTile extends StatelessWidget {
    final ScheduleCandidate candidate;
    final bool recommended;

    const _CandidateTile({required this.candidate, required this.recommended});

    @override
    Widget build(BuildContext context) {
        final c = candidate;
        final color = c.feasible ? AppColors.success : AppColors.error;
        return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: color.withValues(alpha: 0.4))),
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                        Expanded(
                            child: Text('Start ${formatDate(c.start)}',
                                style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (recommended) const StatusChip('Recommended', AppColors.success),
                        if (!c.feasible) const StatusChip('Does not fit', AppColors.error),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                        'Transfer ${formatDate(c.transferDate)} · Hatch ${formatDate(c.hatchDate)} · House ${formatDate(c.houseArrivalDate)}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary(context))),
                    ...c.reasons.map((r) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $r', style: const TextStyle(fontSize: 12)))),
                ]),
            ),
        );
    }
}

class _ResultSummary extends StatelessWidget {
    final ScheduleOptions options;

    const _ResultSummary(this.options);

    Widget _stat(BuildContext context, IconData icon, String value, String label, Color color) =>
        Expanded(
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(height: 4),
                    Text(value,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                    Text(label,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                ]),
            ),
        );

    @override
    Widget build(BuildContext context) {
        final fits = options.candidates.where((c) => c.feasible).length;
        final secondary = AppColors.textSecondary(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
                _stat(context, Icons.egg_outlined, '${options.eggs}', 'Eggs to set', AppColors.warning),
                const SizedBox(width: 8),
                _stat(context, AppIcons.chick, '~${options.expectedChicks}',
                    'Expected chicks', AppColors.success),
                const SizedBox(width: 8),
                _stat(context, Icons.event_available_outlined, '$fits / ${options.candidates.length}',
                    'Dates that fit', AppColors.info),
            ]),
            const SizedBox(height: 10),
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(options.explanation, style: const TextStyle(fontSize: 13)),
            ),
            if (options.windows.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('You can start between',
                    style: TextStyle(fontSize: 12, color: secondary)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 6, children: options.windows
                    .map((w) => Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: const Icon(Icons.date_range, size: 16, color: AppColors.success),
                        label: Text('${formatDate(w.from)} – ${formatDate(w.to)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        side: BorderSide(color: AppColors.success.withValues(alpha: 0.4)),
                        backgroundColor: AppColors.success.withValues(alpha: 0.1)))
                    .toList()),
            ],
            if (options.assumptions.isNotEmpty)
                Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('Assumptions',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        children: options.assumptions
                            .map((a) => Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text('• $a',
                                        style: TextStyle(fontSize: 12, color: secondary)))))
                            .toList(),
                    ),
                ),
        ]);
    }
}
