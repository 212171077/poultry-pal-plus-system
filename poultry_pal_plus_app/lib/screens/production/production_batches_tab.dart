import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_icons.dart';
import 'package:intl/intl.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../models/incubation_batch.dart';
import '../../models/production_reminder.dart';
import '../../models/production_settings.dart';
import '../../models/production_snapshot.dart';
import '../../service/production_service.dart';
import 'production_hatch_tab.dart' show ResultForm;
import 'production_widgets.dart';

String batchStatusLabel(BatchStatus s) => switch (s) {
        BatchStatus.planned => 'Planned',
        BatchStatus.incubating => 'Incubating',
        BatchStatus.transferred => 'In hatcher',
        BatchStatus.completed => 'Completed',
        BatchStatus.cancelled => 'Cancelled',
    };

Color batchStatusColor(BatchStatus s) => switch (s) {
        BatchStatus.planned => AppColors.info,
        BatchStatus.incubating => AppColors.warning,
        BatchStatus.transferred => AppColors.secondaryDark,
        BatchStatus.completed => AppColors.success,
        BatchStatus.cancelled => AppColors.error,
    };

String cycleStatusLabel(CycleStatus s) => switch (s) {
        CycleStatus.reserved => 'Reserved',
        CycleStatus.inHatcher => 'In hatcher',
        CycleStatus.completed => 'Completed',
        CycleStatus.cancelled => 'Cancelled',
    };

/// Reference suggestion, e.g. NOV03-1000.
String suggestReference(DateTime start, int eggs) =>
    '${DateFormat('MMMdd').format(start).toUpperCase()}-$eggs';

class ProductionBatchesTab extends StatelessWidget {
    final ProductionSnapshot data;
    final Future<void> Function() onChanged;
    final bool canManage;

    const ProductionBatchesTab(
        {super.key, required this.data, required this.onChanged, required this.canManage});

    List<ProductionEquipment> _equipment(EquipmentType type) => data.equipment
        .where((e) => e.type == type && e.enabled)
        .toList();

    String _name(String id) {
        for (final e in data.equipment) {
            if (e.id == id) return e.name;
        }
        return 'Equipment';
    }

    Future<void> _newBatch(BuildContext context) async {
        final created = await showFormSheet<bool>(
            context,
            title: 'New incubation batch',
            info: 'Records a set of eggs placed in an incubator. A reference is generated from the start date and number of eggs, and you can change it.',
            builder: (_) => _NewBatchForm(incubators: _equipment(EquipmentType.incubator)),
        );
        if (created == true) await onChanged();
    }

    Widget _stat(BuildContext context, IconData icon, String label, int value, Color color) =>
        Expanded(
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(height: 4),
                    Text('$value',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                    Text(label,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                ]),
            ),
        );

    Widget _summary(BuildContext context, List<IncubationBatch> batches) {
        int count(bool Function(IncubationBatch) f) => batches.where(f).length;
        return Row(children: [
            _stat(context, Icons.schedule, 'Planned',
                count((b) => b.status == BatchStatus.planned), AppColors.info),
            const SizedBox(width: 8),
            _stat(context, AppIcons.incubate, 'Incubating',
                count((b) => b.status == BatchStatus.incubating), AppColors.warning),
            const SizedBox(width: 8),
            _stat(context, AppIcons.hatch, 'In hatcher',
                count((b) => b.status == BatchStatus.transferred), AppColors.secondaryDark),
            const SizedBox(width: 8),
            _stat(context, Icons.check_circle_outline, 'Done',
                count((b) => b.status == BatchStatus.completed), AppColors.success),
        ]);
    }

    @override
    Widget build(BuildContext context) {
        final batches = [...data.batches]
            ..sort((a, b) => b.plannedStartDate.compareTo(a.plannedStartDate));
        final open = data.reminders
            .where((r) => r.status == ReminderStatus.open)
            .toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
        return RefreshIndicator(
            onRefresh: onChanged,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                    SectionTitle('Incubation batches',
                        info: 'A batch is a set of eggs in an incubator. Around day ${data.settings.transferDay} the eggs move to a hatcher, where the chicks hatch.',
                        trailing: canManage
                            ? IconButton.filled(
                                onPressed: () => _newBatch(context),
                                icon: const Icon(Icons.add),
                                tooltip: 'New batch',
                            )
                            : null),
                    if (batches.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _summary(context, batches),
                    ],
                    if (open.isNotEmpty) ...[
                        SectionTitle('Production tasks (${open.length})',
                            info: 'Tasks created for your batches, such as transferring eggs to the hatcher or recording hatch results.'),
                        ...open.map((r) => _ReminderTile(
                            reminder: r, canManage: canManage, onChanged: onChanged)),
                        const SizedBox(height: 8),
                    ],
                    if (batches.isEmpty)
                        const EmptyState(
                            icon: Icons.egg_outlined,
                            message: 'No batches yet. Tap New batch to set your first eggs.')
                    else
                        ...batches.map((b) => _BatchCard(
                            batch: b,
                            incubator: _name(b.equipmentId),
                            hatchers: _equipment(EquipmentType.hatcher),
                            hatcherName: _name,
                            canManage: canManage,
                            onChanged: onChanged,
                        )),
                ],
            ),
        );
    }
}

class _NewBatchForm extends StatefulWidget {
    final List<ProductionEquipment> incubators;

    const _NewBatchForm({required this.incubators});

    @override
    State<_NewBatchForm> createState() => _NewBatchFormState();
}

class _NewBatchFormState extends State<_NewBatchForm> {
    final _eggs = TextEditingController();
    final _reference = TextEditingController();
    final _source = TextEditingController();
    DateTime _start = DateTime.now();
    String? _incubatorId;
    bool _referenceEdited = false;
    bool _busy = false;

    @override
    void initState() {
        super.initState();
        if (widget.incubators.isNotEmpty) _incubatorId = widget.incubators.first.id;
    }

    @override
    void dispose() {
        _eggs.dispose();
        _reference.dispose();
        _source.dispose();
        super.dispose();
    }

    void _refreshReference() {
        final eggs = int.tryParse(_eggs.text);
        if (_referenceEdited || eggs == null) return;
        _reference.text = suggestReference(_start, eggs);
    }

    Future<void> _submit() async {
        final eggs = int.tryParse(_eggs.text);
        if (_incubatorId == null || eggs == null || eggs <= 0) {
            showError(context, 'Choose an incubator and enter how many eggs you are setting.');
            return;
        }
        setState(() => _busy = true);
        final ok = await runAction(
            context,
            () => ProductionService().createBatch(
                equipmentId: _incubatorId!,
                eggsSet: eggs,
                plannedStartDate: _start,
                reference: _reference.text.trim(),
                eggSource: _source.text.trim(),
            ),
            success: 'Batch created');
        if (!mounted) return;
        if (ok) {
            Navigator.pop(context, true);
        } else {
            setState(() => _busy = false);
        }
    }

    @override
    Widget build(BuildContext context) => Column(children: [
        DropdownInput<String>(
            label: 'Incubator',
            helper: 'The incubator these eggs will be set in',
            value: _incubatorId,
            items: widget.incubators
                .map((e) => DropdownMenuItem(
                    value: e.id, child: Text('${e.name} (${e.capacity} eggs)')))
                .toList(),
            onChanged: (v) => setState(() => _incubatorId = v),
        ),
        NumberField(
            label: 'Eggs set',
            helper: 'Number of eggs placed in the incubator',
            controller: _eggs,
            onChanged: (_) => setState(_refreshReference),
        ),
        DatePickerField(
            label: 'Start date',
            helper: 'The day the eggs go into the incubator',
            value: _start,
            onChanged: (d) => setState(() {
                _start = d;
                _refreshReference();
            }),
        ),
        TextField(
            controller: _reference,
            onChanged: (_) => _referenceEdited = true,
            decoration: InputDecoration(
                labelText: 'Reference',
                helperText: 'Generated from the date and eggs set. You can change it.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
        ),
        const SizedBox(height: 12),
        AppTextInput(
            label: 'Egg source (optional)',
            helper: 'Where the eggs came from, e.g. own flock or a supplier',
            controller: _source,
        ),
        SubmitButton(label: 'Create batch', busy: _busy, onPressed: _submit),
    ]);
}

class _BatchCard extends StatefulWidget {
    final IncubationBatch batch;
    final String incubator;
    final List<ProductionEquipment> hatchers;
    final String Function(String) hatcherName;
    final bool canManage;
    final Future<void> Function() onChanged;

    const _BatchCard({
        required this.batch,
        required this.incubator,
        required this.hatchers,
        required this.hatcherName,
        required this.canManage,
        required this.onChanged,
    });

    @override
    State<_BatchCard> createState() => _BatchCardState();
}

class _BatchCardState extends State<_BatchCard> {
    final ProductionService _service = ProductionService();
    bool _busy = false;

    Future<void> _run(Future<void> Function() action, String success) async {
        setState(() => _busy = true);
        final ok = await runAction(context, action, success: success);
        if (ok) await widget.onChanged();
        if (mounted) setState(() => _busy = false);
    }

    Future<void> _start() async {
        final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            helpText: 'Actual start date',
        );
        if (date == null) return;
        await _run(() => _service.startBatch(widget.batch.id, actualDate: date),
            'Batch started');
    }

    Future<void> _cancel() async {
        if (!await confirm(context, 'Cancel batch?',
            'Batch ${widget.batch.reference} and its hatcher reservations will be cancelled.',
            action: 'Cancel batch')) {
            return;
        }
        await _run(() => _service.cancelBatch(widget.batch.id), 'Batch cancelled');
    }

    Future<void> _reserve() async {
        final done = await showFormSheet<bool>(
            context,
            title: 'Reserve hatcher',
            info: 'Reserves hatcher space for the eggs that will move from the incubator, so the hatcher is not overbooked.',
            builder: (_) => _ReserveForm(batch: widget.batch, hatchers: widget.hatchers),
        );
        if (done == true) await widget.onChanged();
    }

    Future<void> _transfer(HatcherCycle cycle) async {
        final date = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            helpText: 'Actual transfer date',
        );
        if (date == null) return;
        await _run(() => _service.transferCycle(cycle.id, actualDate: date),
            'Eggs transferred to hatcher');
    }

    Future<void> _recordResult(HatcherCycle cycle) async {
        final done = await showFormSheet<bool>(
            context,
            title: 'Record hatch result',
            info: 'Record how many chicks hatched from this hatcher cycle. Unhatched eggs are calculated for you: eggs transferred minus hatched.',
            builder: (_) => ResultForm(cycle: cycle),
        );
        if (done == true) await widget.onChanged();
    }

    Future<void> _cancelCycle(HatcherCycle cycle) async {
        if (!await confirm(context, 'Cancel reservation?',
            'The hatcher reservation ${cycle.reference} will be released.',
            action: 'Release')) {
            return;
        }
        await _run(() => _service.cancelCycle(cycle.id), 'Reservation cancelled');
    }

    @override
    Widget build(BuildContext context) {
        final b = widget.batch;
        final active = b.status == BatchStatus.planned || b.status == BatchStatus.incubating;
        final color = batchStatusColor(b.status);
        final secondary = AppColors.textSecondary(context);
        final cycles = b.hatcherCycles.where((c) => c.status != CycleStatus.cancelled).toList();
        return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.surface(context),
            child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(width: 5, color: color),
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                    Expanded(
                                        child: Text(b.reference,
                                            style: const TextStyle(
                                                fontSize: 17, fontWeight: FontWeight.bold)),
                                    ),
                                    StatusChip(batchStatusLabel(b.status), color),
                                ]),
                                const SizedBox(height: 2),
                                Row(children: [
                                    Icon(Icons.device_thermostat, size: 14, color: secondary),
                                    const SizedBox(width: 4),
                                    Text('${widget.incubator} · ${b.eggsSet} eggs set',
                                        style: TextStyle(fontSize: 12, color: secondary)),
                                ]),
                                const SizedBox(height: 12),
                                _stages(b),
                                const SizedBox(height: 12),
                                _allocation(b),
                                if (cycles.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Text('Hatcher cycles',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: secondary)),
                                    const SizedBox(height: 6),
                                    ...cycles.map(_cycleRow),
                                ],
                                if (widget.canManage && active) ...[
                                    const Divider(height: 20),
                                    _busy
                                        ? const Center(child: CircularProgressIndicator())
                                        : Wrap(spacing: 4, runSpacing: 4, children: [
                                            if (b.status == BatchStatus.planned)
                                                IconButton.filledTonal(
                                                    onPressed: _start,
                                                    icon: const Icon(Icons.play_arrow),
                                                    tooltip: 'Start incubation'),
                                            if (b.eggsUnassigned > 0)
                                                IconButton.outlined(
                                                    onPressed: _reserve,
                                                    icon: const Icon(Icons.bookmark_add_outlined),
                                                    tooltip: 'Reserve hatcher'),
                                            IconButton(
                                                onPressed: _cancel,
                                                color: AppColors.error,
                                                icon: const Icon(Icons.cancel_outlined),
                                                tooltip: 'Cancel batch'),
                                        ]),
                                ],
                            ]),
                        ),
                    ),
                ]),
            ),
        );
    }

    Widget _stage(IconData icon, String label, DateTime date, bool done) {
        final color = done ? AppColors.success : AppColors.textSecondary(context);
        return Expanded(
            child: Column(children: [
                Icon(done ? Icons.check_circle : icon, size: 20, color: color),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                Text(formatDate(date),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
        );
    }

    Widget _stages(IncubationBatch b) {
        final started = b.actualStartDate != null || b.status != BatchStatus.planned;
        final transferred = b.hatcherCycles.any((c) => c.actualTransferDate != null);
        final hatched = b.status == BatchStatus.completed;
        return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
                color: AppColors.textSecondary(context).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
                _stage(AppIcons.incubate, 'Start', b.actualStartDate ?? b.plannedStartDate, started),
                _stage(AppIcons.transfer, 'Transfer', b.plannedTransferDate, transferred),
                _stage(AppIcons.hatch, 'Hatch', b.plannedHatchDate, hatched),
            ]),
        );
    }

    Widget _allocation(IncubationBatch b) {
        final total = b.eggsSet == 0 ? 1 : b.eggsSet;
        final ratio = (b.eggsReserved / total).clamp(0.0, 1.0);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
                Text('Hatcher allocation',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                const Spacer(),
                Text('${b.eggsReserved} reserved · ${b.eggsUnassigned} unassigned',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: AppColors.secondaryDark,
                    backgroundColor: AppColors.warning.withValues(alpha: 0.25)),
            ),
        ]);
    }

    Widget _cycleRow(HatcherCycle c) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.textSecondary(context).withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
            const Icon(AppIcons.chick, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${widget.hatcherName(c.hatcherId)} · ${c.quantity} eggs',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                        '${cycleStatusLabel(c.status)} · hatch ${formatDate(c.expectedHatchDate)}',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary(context))),
                ]),
            ),
            if (widget.canManage && c.status == CycleStatus.inHatcher)
                IconButton(
                    icon: const Icon(Icons.fact_check_outlined),
                    tooltip: 'Record hatch result',
                    onPressed: _busy ? null : () => _recordResult(c)),
            if (widget.canManage && c.status == CycleStatus.reserved) ...[
                IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    tooltip: 'Transfer to hatcher',
                    onPressed: _busy ? null : () => _transfer(c)),
                IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Release reservation',
                    onPressed: _busy ? null : () => _cancelCycle(c)),
            ],
        ]),
    );
}

class _ReserveForm extends StatefulWidget {
    final IncubationBatch batch;
    final List<ProductionEquipment> hatchers;

    const _ReserveForm({required this.batch, required this.hatchers});

    @override
    State<_ReserveForm> createState() => _ReserveFormState();
}

class _ReserveFormState extends State<_ReserveForm> {
    late final TextEditingController _quantity =
        TextEditingController(text: '${widget.batch.eggsUnassigned}');
    String? _hatcherId;
    bool _busy = false;

    @override
    void initState() {
        super.initState();
        if (widget.hatchers.isNotEmpty) _hatcherId = widget.hatchers.first.id;
    }

    @override
    void dispose() {
        _quantity.dispose();
        super.dispose();
    }

    Future<void> _submit() async {
        final qty = int.tryParse(_quantity.text);
        if (_hatcherId == null || qty == null || qty <= 0) {
            showError(context, 'Choose a hatcher and enter the number of eggs.');
            return;
        }
        setState(() => _busy = true);
        final ok = await runAction(
            context,
            () => ProductionService().reserveCycle(widget.batch.id, _hatcherId!, qty),
            success: 'Hatcher reserved');
        if (!mounted) return;
        if (ok) {
            Navigator.pop(context, true);
        } else {
            setState(() => _busy = false);
        }
    }

    @override
    Widget build(BuildContext context) => Column(children: [
        DropdownInput<String>(
            label: 'Hatcher',
            helper: 'The hatcher that will receive these eggs',
            value: _hatcherId,
            items: widget.hatchers
                .map((e) => DropdownMenuItem(
                    value: e.id, child: Text('${e.name} (${e.capacity} eggs)')))
                .toList(),
            onChanged: (v) => setState(() => _hatcherId = v),
        ),
        NumberField(
            label: 'Eggs to transfer',
            helper: '${widget.batch.eggsUnassigned} eggs are not yet assigned to a hatcher',
            controller: _quantity,
        ),
        SubmitButton(label: 'Reserve', busy: _busy, onPressed: _submit),
    ]);
}

class _ReminderTile extends StatefulWidget {
    final ProductionReminder reminder;
    final bool canManage;
    final Future<void> Function() onChanged;

    const _ReminderTile(
        {required this.reminder, required this.canManage, required this.onChanged});

    @override
    State<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<_ReminderTile> {
    bool _busy = false;

    Future<void> _complete() async {
        setState(() => _busy = true);
        final ok = await runAction(
            context,
            () => ProductionService().completeReminder(widget.reminder.id),
            success: 'Task completed');
        if (ok) await widget.onChanged();
        if (mounted) setState(() => _busy = false);
    }

    @override
    Widget build(BuildContext context) {
        final r = widget.reminder;
        final color = r.overdue ? AppColors.error : AppColors.info;
        return SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
                Icon(r.overdue ? Icons.warning_amber_rounded : Icons.schedule, color: color),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                            '${formatDate(r.dueDate)}${r.sourceReference != null ? ' · ${r.sourceReference}' : ''}',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary(context))),
                    ]),
                ),
                if (r.overdue) StatusChip('Overdue', color),
                if (widget.canManage)
                    _busy
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            tooltip: 'Mark as done',
                            onPressed: _complete,
                        ),
            ]),
        );
    }
}
