import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_icons.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../models/bird_placement.dart';
import '../../models/incubation_batch.dart';
import '../../models/production_snapshot.dart';
import '../../service/production_service.dart';
import 'production_widgets.dart';

String movementLabel(MovementType t) => switch (t) {
        MovementType.mortality => 'Mortality',
        MovementType.sale => 'Sale',
        MovementType.transfer => 'Transfer',
        MovementType.otherRemoval => 'Other removal',
        MovementType.correction => 'Correction',
    };

class ProductionPlacementsTab extends StatelessWidget {
    final ProductionSnapshot data;
    final Future<void> Function() onChanged;
    final bool canManage;

    const ProductionPlacementsTab(
        {super.key, required this.data, required this.onChanged, required this.canManage});

    String _houseName(String id) {
        for (final h in data.occupancy) {
            if (h.houseId == id) return h.name;
        }
        return 'Chicken house';
    }

    Future<void> _place(BuildContext context) async {
        final cycles = [
            for (final b in data.batches)
                for (final c in b.hatcherCycles)
                    if (c.status == CycleStatus.completed || c.status == CycleStatus.inHatcher) c,
        ];
        final done = await showFormSheet<bool>(
            context,
            title: 'Place chicks',
            info: 'Records chicks moving into a chicken house, either from your own hatch or bought as day-old chicks. The house capacity is checked for you.',
            builder: (_) => _PlaceForm(houses: data.occupancy, cycles: cycles),
        );
        if (done == true) await onChanged();
    }

    Future<void> _movement(BuildContext context, BirdPlacement p) async {
        final done = await showFormSheet<bool>(
            context,
            title: 'Record bird movement',
            info: 'Record birds that died, were sold, moved or otherwise removed from ${p.reference}. Use Correction to fix a counting mistake.',
            builder: (_) => _MovementForm(placement: p),
        );
        if (done == true) await onChanged();
    }

    Widget _overview(BuildContext context) {
        final houses = data.occupancy.where((h) => h.enabled);
        final capacity = houses.fold<int>(0, (a, h) => a + h.capacity);
        final birds = data.occupancy.fold<int>(0, (a, h) => a + h.occupied);
        Widget stat(IconData icon, String value, String label, Color color) => Expanded(
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
        return Row(children: [
            stat(AppIcons.house, '${data.occupancy.length}', 'Houses', AppColors.info),
            const SizedBox(width: 8),
            stat(AppIcons.chicken, '$birds', 'Birds', AppColors.warning),
            const SizedBox(width: 8),
            stat(Icons.event_seat_outlined, '${(capacity - birds).clamp(0, capacity)}', 'Free space',
                AppColors.success),
        ]);
    }

    @override
    Widget build(BuildContext context) {
        final placements = [...data.placements]
            ..sort((a, b) {
                if (a.active != b.active) return a.active ? -1 : 1;
                return b.placementDate.compareTo(a.placementDate);
            });
        return RefreshIndicator(
            onRefresh: onChanged,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                    const SectionTitle('Chicken houses',
                        info: 'Each house has a capacity. Placements show the chicks currently growing in it.',
                    ),
                    if (canManage) ...[
                        FilledButton.icon(
                            onPressed: () => _place(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Place chicks')),
                        const SizedBox(height: 8),
                    ],
                    if (data.occupancy.isEmpty)
                        const EmptyState(
                            icon: Icons.home_work_outlined,
                            message: 'No chicken houses configured. Add them in Settings.')
                    else ...[
                        _overview(context),
                        const SizedBox(height: 6),
                        ...data.occupancy.map((h) => _HouseCard(house: h)),
                    ],
                    const SectionTitle('Placements',
                        info: 'Each placement is a group of chicks moved into a house. Record deaths, sales and other removals against it.'),
                    if (placements.isEmpty)
                        const EmptyState(
                            icon: AppIcons.chick, message: 'No chicks placed yet.')
                    else
                        ...placements.map((p) => _PlacementCard(
                            placement: p,
                            house: _houseName(p.houseId),
                            canManage: canManage,
                            onMovement: () => _movement(context, p),
                        )),
                ],
            ),
        );
    }
}

class _HouseCard extends StatelessWidget {
    final HouseOccupancy house;

    const _HouseCard({required this.house});

    @override
    Widget build(BuildContext context) {
        final ratio =
            house.capacity == 0 ? 0.0 : (house.occupied / house.capacity).clamp(0.0, 1.0);
        final color = !house.enabled
            ? AppColors.textSecondary(context)
            : ratio >= 0.9
                ? AppColors.error
                : ratio >= 0.7 ? AppColors.warning : AppColors.success;
        return SectionCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(AppIcons.house, color: color, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(house.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                    if (!house.enabled)
                        StatusChip('Disabled', color)
                    else
                        Text('${(ratio * 100).round()}% full',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15)),
                ),
                const SizedBox(height: 6),
                Text('${house.occupied} of ${house.capacity} birds · ${house.available} free',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
            ]),
        );
    }
}

class _PlacementCard extends StatelessWidget {
    final BirdPlacement placement;
    final String house;
    final bool canManage;
    final VoidCallback onMovement;

    const _PlacementCard(
        {required this.placement,
        required this.house,
        required this.canManage,
        required this.onMovement});

    Widget _stat(BuildContext context, String value, String label, Color color) => Expanded(
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
                Text(value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
                Text(label,
                    style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary(context))),
            ]),
        ),
    );

    @override
    Widget build(BuildContext context) {
        final p = placement;
        final accent = p.active ? AppColors.success : AppColors.textSecondary(context);
        final secondary = AppColors.textSecondary(context);
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
                                        child: Text(p.reference,
                                            style: const TextStyle(
                                                fontSize: 16, fontWeight: FontWeight.bold))),
                                    StatusChip(p.active ? 'Active' : 'Closed', accent),
                                ]),
                                Row(children: [
                                    Icon(AppIcons.house, size: 14, color: secondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                        child: Text('$house · placed ${formatDate(p.placementDate)}',
                                            style: TextStyle(fontSize: 12, color: secondary))),
                                ]),
                                if (canManage && p.active) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                            onPressed: onMovement,
                                            icon: const Icon(AppIcons.transfer),
                                            label: const Text('Record bird movement')),
                                    ),
                                ],
                                const SizedBox(height: 12),
                                Row(children: [
                                    _stat(context, '${p.quantity}', 'Placed', AppColors.info),
                                    const SizedBox(width: 6),
                                    _stat(context, '${p.remaining}', 'Remaining', AppColors.success),
                                    const SizedBox(width: 6),
                                    _stat(context, '${p.mortality}', 'Died', AppColors.error),
                                    const SizedBox(width: 6),
                                    _stat(context, '${p.sold}', 'Sold', AppColors.warning),
                                    const SizedBox(width: 6),
                                    _stat(context, '${p.otherRemovals}', 'Other', secondary),
                                ]),
                            ]),
                        ),
                    ),
                ]),
            ),
        );
    }
}

class _PlaceForm extends StatefulWidget {
    final List<HouseOccupancy> houses;
    final List<HatcherCycle> cycles;

    const _PlaceForm({required this.houses, required this.cycles});

    @override
    State<_PlaceForm> createState() => _PlaceFormState();
}

class _PlaceFormState extends State<_PlaceForm> {
    final _quantity = TextEditingController();
    final _age = TextEditingController(text: '0');
    final _supplier = TextEditingController();
    PlacementSource _source = PlacementSource.purchasedDayOld;
    HouseOccupancy? _house;
    String? _cycleId;
    DateTime _date = DateTime.now();
    bool _busy = false;

    @override
    void initState() {
        super.initState();
        final enabled = widget.houses.where((h) => h.enabled).toList();
        if (enabled.isNotEmpty) _house = enabled.first;
        if (widget.cycles.isNotEmpty) _cycleId = widget.cycles.first.id;
        _fillFreeSpace();
    }

    @override
    void dispose() {
        _quantity.dispose();
        _age.dispose();
        _supplier.dispose();
        super.dispose();
    }

    void _fillFreeSpace() {
        final free = _house?.available;
        if (free != null && free > 0) _quantity.text = '$free';
    }

    Future<void> _submit() async {
        final qty = int.tryParse(_quantity.text);
        if (_house == null || qty == null || qty <= 0) {
            showError(context, 'Choose a house and enter how many chicks you are placing.');
            return;
        }
        if (_source == PlacementSource.ownHatch && _cycleId == null) {
            showError(context, 'Choose the hatcher cycle these chicks came from.');
            return;
        }
        setState(() => _busy = true);
        final own = _source == PlacementSource.ownHatch;
        final ok = await runAction(
            context,
            () => ProductionService().placeChicks(
                source: _source,
                houseId: _house!.houseId,
                quantity: qty,
                placementDate: _date,
                sourceCycleId: own ? _cycleId : null,
                sourceReference: own ? null : _supplier.text.trim(),
                ageDaysAtArrival: own ? null : int.tryParse(_age.text) ?? 0,
            ),
            success: 'Chicks placed');
        if (!mounted) return;
        if (ok) {
            Navigator.pop(context, true);
        } else {
            setState(() => _busy = false);
        }
    }

    @override
    Widget build(BuildContext context) => Column(children: [
        DropdownInput<HouseOccupancy>(
            label: 'Chicken house',
            helper: _house == null ? null : '${_house!.available} birds of space free',
            value: _house,
            items: widget.houses
                .where((h) => h.enabled)
                .map((h) => DropdownMenuItem(value: h, child: Text(h.name)))
                .toList(),
            onChanged: (v) => setState(() {
                _house = v;
                _fillFreeSpace();
            }),
        ),
        DropdownInput<PlacementSource>(
            label: 'Source',
            helper: 'Where the chicks came from',
            value: _source,
            items: const [
                DropdownMenuItem(
                    value: PlacementSource.purchasedDayOld, child: Text('Bought day-old chicks')),
                DropdownMenuItem(value: PlacementSource.ownHatch, child: Text('Own hatch')),
            ],
            onChanged: (v) => setState(() => _source = v ?? _source),
        ),
        if (_source == PlacementSource.ownHatch)
            DropdownInput<String>(
                label: 'Hatcher cycle',
                helper: 'The hatched batch these chicks belong to',
                value: _cycleId,
                items: widget.cycles
                    .map((c) => DropdownMenuItem(value: c.id, child: Text(c.reference)))
                    .toList(),
                onChanged: (v) => setState(() => _cycleId = v),
            )
        else ...[
            AppTextInput(
                label: 'Supplier (optional)',
                helper: 'Who you bought the chicks from',
                controller: _supplier),
            NumberField(
                label: 'Age on arrival (days)',
                helper: '0 for day-old chicks',
                controller: _age),
        ],
        NumberField(
            label: 'Chicks',
            helper: 'Filled with the free space; change if needed',
            controller: _quantity,
        ),
        DatePickerField(
            label: 'Placement date',
            helper: 'The day the chicks went into the house',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
        ),
        SubmitButton(label: 'Place chicks', busy: _busy, onPressed: _submit),
    ]);
}

class _MovementForm extends StatefulWidget {
    final BirdPlacement placement;

    const _MovementForm({required this.placement});

    @override
    State<_MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends State<_MovementForm> {
    final _count = TextEditingController();
    final _reason = TextEditingController();
    // Reused on retry so a movement is never recorded twice.
    final String _key = DateTime.now().microsecondsSinceEpoch.toString();
    MovementType _type = MovementType.mortality;
    DateTime _date = DateTime.now();
    bool _increase = false;
    bool _busy = false;

    @override
    void dispose() {
        _count.dispose();
        _reason.dispose();
        super.dispose();
    }

    Future<void> _submit() async {
        final count = int.tryParse(_count.text);
        if (count == null || count <= 0) {
            showError(context, 'Enter how many birds.');
            return;
        }
        setState(() => _busy = true);
        final ok = await runAction(
            context,
            () => ProductionService().addMovement(
                widget.placement.id,
                type: _type,
                count: count,
                date: _date,
                idempotencyKey: '${widget.placement.id}-$_key',
                increase: _increase,
                reason: _reason.text.trim(),
            ),
            success: 'Movement recorded');
        if (!mounted) return;
        if (ok) {
            Navigator.pop(context, true);
        } else {
            setState(() => _busy = false);
        }
    }

    @override
    Widget build(BuildContext context) => Column(children: [
        DropdownInput<MovementType>(
            label: 'Type',
            helper: '${widget.placement.remaining} birds remaining',
            value: _type,
            items: MovementType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(movementLabel(t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        NumberField(label: 'Birds', helper: 'Number of birds affected', controller: _count),
        DatePickerField(
            label: 'Date',
            helper: 'When it happened',
            value: _date,
            onChanged: (d) => setState(() => _date = d),
        ),
        if (_type == MovementType.correction)
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Add birds'),
                subtitle: const Text('Turn off to remove birds'),
                value: _increase,
                onChanged: (v) => setState(() => _increase = v),
            ),
        AppTextInput(
            label: 'Reason (optional)',
            helper: 'For example the cause of death',
            controller: _reason),
        SubmitButton(label: 'Save', busy: _busy, onPressed: _submit),
    ]);
}
