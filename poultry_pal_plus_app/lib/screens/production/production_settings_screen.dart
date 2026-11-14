import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../models/production_settings.dart';
import '../../service/production_service.dart';
import 'production_widgets.dart';

String _percent(double rate) =>
    (rate * 100).toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

String equipmentTypeLabel(EquipmentType t) => switch (t) {
        EquipmentType.incubator => 'Incubator',
        EquipmentType.hatcher => 'Hatcher',
        EquipmentType.chickenHouse => 'Chicken house',
    };

class ProductionSettingsScreen extends StatefulWidget {
    final bool canManage;

    /// When true it is shown as a tab body, without its own Scaffold.
    final bool embedded;

    const ProductionSettingsScreen({super.key, required this.canManage, this.embedded = false});

    @override
    State<ProductionSettingsScreen> createState() => _ProductionSettingsScreenState();
}

class _ProductionSettingsScreenState extends State<ProductionSettingsScreen> {
    final ProductionService _service = ProductionService();
    ProductionSettings? _settings;
    List<ProductionEquipment> _equipment = [];
    Object? _error;
    bool _loading = true;
    bool _saving = false;

    final _timeZone = TextEditingController();
    final _incubation = TextEditingController();
    final _transfer = TextEditingController();
    final _brooding = TextEditingController();
    final _hatchRate = TextEditingController();
    final _mortality = TextEditingController();
    final _growOut = TextEditingController();
    final _leadTime = TextEditingController();

    @override
    void initState() {
        super.initState();
        _load();
    }

    @override
    void dispose() {
        for (final c in [
            _timeZone, _incubation, _transfer, _brooding, _hatchRate, _mortality,
            _growOut, _leadTime,
        ]) {
            c.dispose();
        }
        super.dispose();
    }

    Future<void> _load() async {
        try {
            final settings = await _service.getSettings();
            final equipment = await _service.getEquipment();
            if (!mounted) return;
            setState(() {
                _settings = settings;
                _equipment = equipment;
                _fill(settings);
                _loading = false;
                _error = null;
            });
        } catch (e) {
            if (!mounted) return;
            setState(() {
                _error = e;
                _loading = false;
            });
        }
    }

    void _fill(ProductionSettings s) {
        _timeZone.text = s.timeZone;
        _incubation.text = '${s.incubationDays}';
        _transfer.text = '${s.transferDay}';
        _brooding.text = '${s.broodingDays}';
        _hatchRate.text = _percent(s.expectedHatchRate);
        _mortality.text = _percent(s.expectedMortalityRate);
        _growOut.text = '${s.defaultGrowOutDays}';
        _leadTime.text = s.supplierLeadTimeDays?.toString() ?? '';
    }

    Future<void> _save() async {
        final current = _settings;
        final incubation = int.tryParse(_incubation.text);
        final transfer = int.tryParse(_transfer.text);
        final brooding = int.tryParse(_brooding.text);
        final hatch = double.tryParse(_hatchRate.text);
        final mortality = double.tryParse(_mortality.text);
        final growOut = int.tryParse(_growOut.text);
        if (current == null ||
            _timeZone.text.trim().isEmpty ||
            incubation == null || transfer == null || brooding == null ||
            hatch == null || mortality == null || growOut == null) {
            showError(context, 'Fill in all the required fields with valid numbers.');
            return;
        }
        if (hatch < 0 || hatch > 100 || mortality < 0 || mortality > 100) {
            showError(context, 'Rates must be between 0 and 100 percent.');
            return;
        }
        setState(() => _saving = true);
        final ok = await runAction(context, () async {
            final saved = await _service.updateSettings(ProductionSettings(
                id: current.id,
                timeZone: _timeZone.text.trim(),
                incubationDays: incubation,
                transferDay: transfer,
                broodingDays: brooding,
                expectedHatchRate: hatch / 100,
                expectedMortalityRate: mortality / 100,
                defaultGrowOutDays: growOut,
                supplierLeadTimeDays: int.tryParse(_leadTime.text),
                estimatesOnly: current.estimatesOnly,
                version: current.version,
            ));
            if (mounted) {
                setState(() {
                    _settings = saved;
                    _fill(saved);
                });
            }
        }, success: 'Settings saved');
        if (!ok) await _load();
        if (mounted) setState(() => _saving = false);
    }

    @override
    Widget build(BuildContext context) {
        final primary = AppColors.adaptivePrimary(context);
        final body = _loading
            ? const Center(child: CircularProgressIndicator())
            : _settings == null
                ? Center(
                    child: EmptyState(
                        icon: Icons.cloud_off_outlined,
                        message: _error == null ? 'Could not load settings' : errorMessage(_error!)))
                : _content();
        if (widget.embedded) return body;
        return Scaffold(
            appBar: AppBar(
                title: Text('Production settings',
                    style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
                backgroundColor: AppColors.surface(context),
                foregroundColor: primary,
                surfaceTintColor: Colors.transparent,
            ),
            body: body,
        );
    }

    Widget _content() {
        final enabled = widget.canManage;
        return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
                const SectionTitle('Timings and rates',
                    info: 'These values drive every calculation: when eggs move to the hatcher, how many eggs you need and when chicks are ready.'),
                SectionCard(
                    child: IgnorePointer(
                        ignoring: !enabled,
                        child: Column(children: [
                            AppTextInput(
                                label: 'Time zone',
                                helper: 'Used to work out today\'s date, e.g. Africa/Johannesburg',
                                controller: _timeZone),
                            NumberField(
                                label: 'Incubation days',
                                helper: 'Days from setting eggs to hatching (21 for chickens)',
                                controller: _incubation),
                            NumberField(
                                label: 'Transfer day',
                                helper: 'Incubation day eggs move to the hatcher',
                                controller: _transfer),
                            NumberField(
                                label: 'Brooding days',
                                helper: 'Days chicks are kept warm after hatching',
                                controller: _brooding),
                            NumberField(
                                label: 'Expected hatch rate (%)',
                                helper: 'Share of eggs you expect to hatch',
                                controller: _hatchRate,
                                decimal: true),
                            NumberField(
                                label: 'Expected mortality (%)',
                                helper: 'Share of chicks you expect to lose while growing',
                                controller: _mortality,
                                decimal: true),
                            NumberField(
                                label: 'Default grow-out days',
                                helper: 'Days birds stay in the house before leaving',
                                controller: _growOut),
                            NumberField(
                                label: 'Supplier lead time (days)',
                                helper: 'Days between ordering and chicks arriving. Used for the Order by date.',
                                controller: _leadTime),
                            if (enabled)
                                SubmitButton(label: 'Save settings', busy: _saving, onPressed: _save),
                        ]),
                    ),
                ),
                const SectionTitle('Equipment capacity',
                    info: 'How many eggs each incubator and hatcher holds, and how many birds each chicken house holds. Disabled equipment is ignored in planning.'),
                if (_equipment.isEmpty)
                    const EmptyState(icon: Icons.precision_manufacturing_outlined, message: 'No equipment found.')
                else
                    ..._equipment.map((e) => _EquipmentTile(
                        key: ValueKey('${e.id}-${e.version}'),
                        item: e,
                        canManage: enabled,
                        onSaved: _load,
                    )),
            ],
        );
    }
}

class _EquipmentTile extends StatefulWidget {
    final ProductionEquipment item;
    final bool canManage;
    final Future<void> Function() onSaved;

    const _EquipmentTile(
        {super.key, required this.item, required this.canManage, required this.onSaved});

    @override
    State<_EquipmentTile> createState() => _EquipmentTileState();
}

class _EquipmentTileState extends State<_EquipmentTile> {
    late final TextEditingController _capacity =
        TextEditingController(text: '${widget.item.capacity}');
    late bool _enabled = widget.item.enabled;
    bool _busy = false;

    @override
    void dispose() {
        _capacity.dispose();
        super.dispose();
    }

    Future<void> _save() async {
        final capacity = int.tryParse(_capacity.text);
        if (capacity == null || capacity <= 0) {
            showError(context, 'Capacity must be more than zero.');
            return;
        }
        final i = widget.item;
        setState(() => _busy = true);
        final ok = await runAction(
            context,
            () => ProductionService().updateEquipment(ProductionEquipment(
                id: i.id,
                type: i.type,
                name: i.name,
                capacity: capacity,
                enabled: _enabled,
                hatcherOccupancyDays: i.hatcherOccupancyDays,
                notes: i.notes,
                version: i.version,
            )),
            success: '${i.name} saved');
        if (ok) await widget.onSaved();
        if (mounted) setState(() => _busy = false);
    }

    @override
    Widget build(BuildContext context) {
        final i = widget.item;
        final unit = i.type == EquipmentType.chickenHouse ? 'birds' : 'eggs';
        return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(i.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            Text(
                                _enabled
                                    ? '${equipmentTypeLabel(i.type)} · $unit'
                                    : '${equipmentTypeLabel(i.type)} · ignored when planning',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary(context))),
                        ]),
                    ),
                    SizedBox(
                        width: 84,
                        child: TextField(
                            controller: _capacity,
                            enabled: widget.canManage,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                                isDense: true,
                                labelText: 'Capacity',
                                labelStyle: const TextStyle(fontSize: 12),
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                        ),
                    ),
                    Transform.scale(
                        scale: 0.8,
                        child: Switch(
                            value: _enabled,
                            onChanged:
                                widget.canManage ? (v) => setState(() => _enabled = v) : null),
                    ),
                    if (widget.canManage)
                        _busy
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2)))
                            : IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Save ${i.name}',
                                icon: const Icon(Icons.check_circle_outline),
                                onPressed: _save),
                ]),
            ),
        );
    }
}
