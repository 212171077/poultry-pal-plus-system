import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_icons.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../models/hatch_result.dart';
import '../../models/incubation_batch.dart';
import '../../models/production_snapshot.dart';
import '../../service/production_service.dart';
import 'production_widgets.dart';

String _rate(double? r) => r == null ? 'n/a' : '${r.toStringAsFixed(1)}%';

/// Hatch results: summary, trend by period and every past result, as on the web.
class ProductionHatchTab extends StatefulWidget {
    final ProductionSnapshot data;
    final Future<void> Function() onChanged;
    final bool canManage;

    const ProductionHatchTab(
        {super.key, required this.data, required this.onChanged, required this.canManage});

    @override
    State<ProductionHatchTab> createState() => _ProductionHatchTabState();
}

class _ProductionHatchTabState extends State<ProductionHatchTab> {
    final ProductionService _service = ProductionService();
    DateTime? _from;
    DateTime? _to;
    late Future<HatchingReport> _report = _load();

    Future<HatchingReport> _load() => _service.getHatchingReport(from: _from, to: _to);

    Future<void> _refresh() async {
        setState(() => _report = _load());
        await widget.onChanged();
    }

    Future<void> _pick(bool from) async {
        final now = DateTime.now();
        final picked = await showDatePicker(
            context: context,
            initialDate: (from ? _from : _to) ?? now,
            firstDate: DateTime(now.year - 5),
            lastDate: DateTime(now.year + 1));
        if (picked == null) return;
        setState(() => from ? _from = picked : _to = picked);
    }

    Widget _dateBox(String label, DateTime? value, bool from) => Expanded(
        child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _pick(from),
            child: InputDecorator(
                decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                    labelStyle: const TextStyle(fontSize: 12),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: value == null
                        ? const Icon(Icons.calendar_today_outlined, size: 14)
                        : InkWell(
                            onTap: () => setState(() => from ? _from = null : _to = null),
                            child: const Icon(Icons.close, size: 16)),
                    suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                child: Text(value == null ? ' ' : formatDate(value),
                    style: const TextStyle(fontSize: 12)),
            ),
        ),
    );

    @override
    Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
                const SectionTitle('Hatch results',
                    info: 'Hatch results are recorded when a batch finishes hatching. This page shows the hatch rate (chicks hatched out of eggs moved to the hatcher), weak chicks, the trend by period and every past result. Filter by date. Record a result from the Batches page.'),
                Text('How well each batch hatched, and the trend over time.',
                    style: TextStyle(color: AppColors.textSecondary(context))),
                const SizedBox(height: 10),
                Row(children: [
                    _dateBox('From', _from, true),
                    const SizedBox(width: 8),
                    _dateBox('To', _to, false),
                    const SizedBox(width: 4),
                    IconButton.filled(
                        onPressed: () => setState(() => _report = _load()),
                        icon: const Icon(Icons.filter_alt_outlined),
                        tooltip: 'Apply filter'),
                ]),
                const SizedBox(height: 6),
                FutureBuilder<HatchingReport>(
                    future: _report,
                    builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                            return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(child: CircularProgressIndicator()));
                        }
                        if (snap.hasError) {
                            return EmptyState(
                                icon: Icons.cloud_off_outlined,
                                message: errorMessage(snap.error!));
                        }
                        return HatchReportCards(report: snap.data!);
                    },
                ),
            ],
        ),
    );
}

class HatchReportCards extends StatelessWidget {
    final HatchingReport report;

    const HatchReportCards({super.key, required this.report});

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
                    FittedBox(
                        child: Text(value,
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold, color: color))),
                    Text(label,
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(context))),
                ]),
            ),
        );

    Widget _counts(BuildContext context,
        {required int hatched, required int eggs, int? unhatched, int? weak}) =>
        LayoutBuilder(builder: (context, constraints) {
            final counts = [
                (AppIcons.chick, '$hatched', 'Chicks hatched', AppColors.success),
                (AppIcons.eggs, '$eggs', 'Eggs moved', AppColors.info),
                if (unhatched != null)
                    (AppIcons.eggs, '$unhatched', 'Unhatched', AppColors.warning),
                if (weak != null)
                    (Icons.monitor_heart_outlined, '$weak', 'Weak chicks', AppColors.error),
            ];
            return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final count in counts)
                    SizedBox(
                        width: (constraints.maxWidth - 8) / 2,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(count.$1, size: 18, color: count.$4),
                            const SizedBox(width: 6),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(count.$2, style: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold)),
                                    Text(count.$3, style: TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary(context))),
                                ],
                            )),
                        ]),
                    ),
            ]);
        });

    Widget _hatchRate(BuildContext context, double? rate) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text('Hatch rate: ${_rate(rate)}',
                style: TextStyle(fontWeight: FontWeight.w700,
                    color: AppColors.adaptivePrimary(context))),
            if (rate != null) ...[
                const SizedBox(height: 6),
                Semantics(
                    label: 'Hatch rate',
                    value: _rate(rate),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: (rate / 100).clamp(0.0, 1.0),
                            minHeight: 6,
                            color: AppColors.success,
                            backgroundColor: AppColors.success.withValues(alpha: 0.12)),
                    ),
                ),
            ],
        ],
    );

    @override
    Widget build(BuildContext context) {
        final s = report.summary;
        if (s.results == 0) {
            return const EmptyState(
                icon: AppIcons.hatch,
                message: 'No hatch results yet. Record a result on a batch once its eggs have hatched.');
        }
        final secondary = AppColors.textSecondary(context);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Summary',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(children: [
                        _stat(context, Icons.percent, _rate(s.hatchRate), 'Hatch rate',
                            AppColors.success),
                        const SizedBox(width: 8),
                        _stat(context, AppIcons.chick, '${s.hatchedChicks}', 'Chicks hatched',
                            AppColors.warning),
                        const SizedBox(width: 8),
                        _stat(context, Icons.egg_outlined, '${s.eggsTransferred}', 'Eggs moved',
                            AppColors.info),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                        '${s.results} results. ${s.weakChicks} chicks were weak (${_rate(s.weakRate)}).',
                        style: TextStyle(fontSize: 12, color: secondary)),
                ]),
            ),
            if (report.trend.isNotEmpty) ...[
                const SectionTitle('Trend by period'),
                for (final period in report.trend)
                    SectionCard(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(period.period, style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 10),
                            _hatchRate(context, period.hatchRate),
                            const SizedBox(height: 12),
                            _counts(context,
                                hatched: period.hatchedChicks, eggs: period.eggsTransferred),
                        ],
                    )),
            ],
            const SectionTitle('History'),
            for (final result in report.rows)
              SectionCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(AppIcons.hatch, color: AppColors.adaptivePrimary(context)),
                        const SizedBox(width: 8),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(result.cycleReference, style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold)),
                                if (result.batchReference.isNotEmpty)
                                    Text('Batch: ${result.batchReference}',
                                        style: TextStyle(fontSize: 12, color: secondary)),
                                Text(formatDate(result.resultDate),
                                    style: TextStyle(fontSize: 12, color: secondary)),
                            ],
                        )),
                    ]),
                    const SizedBox(height: 12),
                    _hatchRate(context, result.hatchRate),
                    const SizedBox(height: 12),
                    _counts(context, hatched: result.hatchedChicks,
                        eggs: result.eggsTransferred, unhatched: result.unhatchedEggs,
                        weak: result.weakChicks),
                ]),
            ),
        ]);
    }
}

class ResultForm extends StatefulWidget {
    final HatcherCycle cycle;

    const ResultForm({super.key, required this.cycle});

    @override
    State<ResultForm> createState() => ResultFormState();
}

class ResultFormState extends State<ResultForm> {
    final _hatched = TextEditingController();
    final _weak = TextEditingController(text: '0');
    final _notes = TextEditingController();
    DateTime _date = DateTime.now();
    bool _busy = false;

    int get _hatchedValue => int.tryParse(_hatched.text) ?? 0;
    int get _unhatched => widget.cycle.quantity - _hatchedValue;

    @override
    void dispose() {
        _hatched.dispose();
        _weak.dispose();
        _notes.dispose();
        super.dispose();
    }

    Future<void> _submit() async {
        final hatched = _hatchedValue;
        final weak = int.tryParse(_weak.text) ?? 0;
        if (hatched < 0 || _unhatched < 0) {
            showError(context, 'Hatched chicks cannot be more than the ${widget.cycle.quantity} eggs transferred.');
            return;
        }
        if (weak > hatched) {
            showError(context, 'Weak chicks are counted among the hatched chicks, so they cannot exceed them.');
            return;
        }
        setState(() => _busy = true);
        final ok = await runAction(
            context,
            () => ProductionService().recordHatchResult(
                widget.cycle.id,
                hatchedChicks: hatched,
                unhatchedEggs: _unhatched,
                weakChicks: weak,
                resultDate: _date,
                notes: _notes.text.trim(),
            ),
            success: 'Hatch result recorded');
        if (!mounted) return;
        if (ok) {
            Navigator.pop(context, true);
        } else {
            setState(() => _busy = false);
        }
    }

    @override
    Widget build(BuildContext context) => Column(children: [
        Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${widget.cycle.reference} · ${widget.cycle.quantity} eggs transferred'),
            ),
        ),
        NumberField(
            label: 'Chicks hatched',
            helper: 'Total live chicks that hatched',
            controller: _hatched,
            onChanged: (_) => setState(() {}),
        ),
        InputDecorator(
            decoration: InputDecoration(
                labelText: 'Unhatched eggs',
                helperText: 'Calculated: eggs transferred minus chicks hatched',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('${_unhatched < 0 ? 0 : _unhatched}'),
        ),
        const SizedBox(height: 12),
        NumberField(
            label: 'Weak chicks',
            helper: 'Of the hatched chicks, how many are weak',
            controller: _weak,
        ),
        DatePickerField(
            label: 'Result date',
            helper: 'The day the chicks were counted',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
        ),
        AppTextInput(label: 'Notes (optional)', controller: _notes),
        SubmitButton(label: 'Save result', busy: _busy, onPressed: _submit),
    ]);
}
