import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_icons.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../models/user.dart';
import '../../models/production_snapshot.dart';
import '../../service/production_service.dart';
import 'production_batches_tab.dart';
import 'production_hatch_tab.dart';
import 'production_overview_tab.dart';
import 'production_placements_tab.dart';
import 'production_plans_tab.dart';
import 'production_settings_screen.dart';
import 'production_widgets.dart';

/// Entry point of the incubation, hatching and chicken-production module.
class ProductionScreen extends StatefulWidget {
  final User user;

  const ProductionScreen({super.key, required this.user});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final ProductionService _service = ProductionService();
  ProductionSnapshot? _data;
  Object? _error;
  bool _loading = true;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snapshot = await _service.getSnapshot();
      if (!mounted) return;
      setState(() {
        _data = snapshot;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppColors.adaptivePrimary(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Production', style: TextStyle(color: primary, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.surface(context),
        foregroundColor: primary,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About production',
            onPressed: () => showInfoDialog(context, 'Production',
                'Plan and track incubation, hatching and growing chickens: set eggs in the incubator, move them to the hatcher, record hatch results, place chicks in a chicken house and plan batches around your capacity.'),
          ),
        ],
      ),
      bottomNavigationBar: _bottomBar(primary),
      body: _body(),
    );
  }

  static const _destinations = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
    (Icons.egg_outlined, Icons.egg_alt, 'Batches'),
    (Icons.edit_calendar_outlined, Icons.edit_calendar, 'Plan'),
    (Icons.event_note_outlined, Icons.event_note, 'Plans'),
    (AppIcons.house, AppIcons.house, 'Houses'),
    (AppIcons.hatch, AppIcons.hatch, 'Hatch'),
    (Icons.tune, Icons.tune, 'Settings'),
  ];

  Widget _bottomBar(Color primary) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        height: 56,
        backgroundColor: AppColors.surface(context),
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withValues(alpha: 0.14),
        labelPadding: EdgeInsets.zero,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 20,
            color: states.contains(WidgetState.selected)
                ? primary
                : AppColors.textSecondary(context))),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 9.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.normal,
            color: states.contains(WidgetState.selected)
                ? primary
                : AppColors.textSecondary(context))),
      ),
      child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.$1),
              selectedIcon: Icon(d.$2),
              label: d.$3,
              tooltip: d.$3,
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final data = _data;
    if (data == null) return _errorView();
    final canManage = widget.user.canManageProduction;
    return IndexedStack(index: _index, children: [
      ProductionOverviewTab(data: data, onChanged: _load, canManage: canManage),
      ProductionBatchesTab(data: data, onChanged: _load, canManage: canManage),
      ProductionScheduleTab(data: data, onChanged: _load),
      ProductionPlansTab(data: data, onChanged: _load, canManage: canManage),
      ProductionPlacementsTab(data: data, onChanged: _load, canManage: canManage),
      ProductionHatchTab(data: data, onChanged: _load, canManage: canManage),
      ProductionSettingsScreen(canManage: canManage, embedded: true),
    ]);
  }

  Widget _errorView() {
    final forbidden =
        _error is ProductionApiException && (_error as ProductionApiException).forbidden;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EmptyState(
            icon: forbidden ? Icons.lock_outline : Icons.cloud_off_outlined,
            message: forbidden
                ? 'You do not have access to production management. Ask the farm owner to grant the Production permission.'
                : '${errorMessage(_error!)}\nCheck your connection and try again.',
          ),
          if (!forbidden)
            FilledButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _load();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
        ]),
      ),
    );
  }
}
