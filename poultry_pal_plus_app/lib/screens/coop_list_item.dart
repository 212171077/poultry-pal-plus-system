import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:flutter_session_manager/flutter_session_manager.dart';
import 'package:poultry_pal_plus_app/models/coop.dart';
import 'package:intl/intl.dart';

import '../models/box_size.dart';
import '../models/egg_packaging_record.dart';
import '../models/egg_size.dart';
import '../models/farm.dart';
import '../models/growing_phase.dart';
import '../models/expense.dart';
import '../models/message_response.dart';
import '../models/mortality.dart';
import '../models/sale.dart';
import '../models/user.dart';
import '../service/poultry_pal_service.dart';
import 'common.dart';
import 'expense_type_dropdown.dart';
import 'mortality_dropdown.dart';

class CoopListItem extends StatefulWidget {
    final Coop coop;
    final Farm farm;
    final User user;
    final VoidCallback onCoopUpdated;

    const CoopListItem({super.key,
        required this.coop,
        required this.farm,
        required this.user,
        required this.onCoopUpdated,
    });

    @override
    _CoopListItemState createState() => _CoopListItemState();
}

class _CoopListItemState extends State<CoopListItem> with SingleTickerProviderStateMixin {
    bool _isExpanded = false;
    PoultryPalService service = PoultryPalService();
    bool isSalesExpanded = false;
    bool isMortalityExpanded = false;
    bool isExpensesExpanded = false;
    late TabController _tabController;
    int _currentTab = 0;

    @override
    void initState() {
        super.initState();
        final tabCount = widget.coop.coopType == 'LAYERS' ? 5 : 4;
        _tabController = TabController(length: tabCount, vsync: this);
        _tabController.addListener(() {
            if (!_tabController.indexIsChanging && mounted) {
                setState(() => _currentTab = _tabController.index);
            }
        });
    }

    @override
    void dispose() {
        _tabController.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final int totalMortalities = widget.coop.mortalities
            .fold<int>(0, (sum, m) => sum + m.numberOfDeaths);
        final double mortalityPct = (widget.coop.numberOfChickens + totalMortalities) > 0
            ? (totalMortalities / (widget.coop.numberOfChickens + totalMortalities)) * 100
            : 0.0;
        final Color mortalityColor = mortalityPct > 5.0 ? AppColors.error : AppColors.success;

        return Dismissible(
            key: ValueKey('coop-swipe-${widget.coop.id}'),
            direction: widget.coop.active
                ? DismissDirection.horizontal
                : DismissDirection.none,
            confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                    if (widget.coop.coopType == 'LAYERS') {
                        _showLayersRecordSalesBottomSheet(
                            widget.coop, widget.farm.id, widget.onCoopUpdated);
                    } else {
                        _showBroilerRecordSalesBottomSheet(
                            widget.coop, widget.farm.id, widget.onCoopUpdated);
                    }
                } else {
                    _showRecordMortalityBottomSheet(
                        widget.coop, widget.farm.id, widget.onCoopUpdated);
                }
                return false;
            },
            background: _buildSwipeBackground(isRight: true),
            secondaryBackground: _buildSwipeBackground(isRight: false),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.border(context), width: 0.3),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isExpanded
                        ? [AppColors.surfaceVariant(context), AppColors.adaptivePrimary(context).withValues(alpha: 0.35)]
                        : [AppColors.surface(context), AppColors.surface(context)],
                ),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                    ),
                ],
            ),
            child: Column(
                children: [
                    ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        leading: Hero(
                            tag: widget.coop.id,
                            child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                    widget.coop.active
                                        ? TweenAnimationBuilder<double>(
                                            tween: Tween(begin: 0.0, end: 1.0),
                                            duration: const Duration(seconds: 2),
                                            curve: Curves.easeInOut,
                                            builder: (context, value, child) {
                                                return Container(
                                                    padding: const EdgeInsets.all(3),
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                            BoxShadow(
                                                                color: AppColors.success.withValues(
                                                                    alpha: (0.3 + (0.1 * value)),
                                                                ),
                                                                blurRadius: 4 + (2 * value),
                                                                spreadRadius: 0.5 + (1 * value),
                                                            ),
                                                        ],
                                                    ),
                                                    child: child,
                                                );
                                            },
                                            onEnd: () {
                                                if (mounted) setState(() {});
                                            },
                                            child: CircleAvatar(
                                                radius: 30,
                                                backgroundImage: AssetImage(widget.coop.imageUrl),
                                            ),
                                        )
                                        : Container(
                                            padding: const EdgeInsets.all(3),
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.white60.withValues(alpha: 0.4),
                                                        blurRadius: 2,
                                                        spreadRadius: 0.5,
                                                    ),
                                                ],
                                            ),
                                            child: CircleAvatar(
                                                radius: 30,
                                                backgroundImage: AssetImage(widget.coop.imageUrl),
                                            ),
                                        ),
                                    // Colored status dot: green = Active, grey = Inactive
                                    Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                            width: 14,
                                            height: 14,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: widget.coop.active
                                                    ? AppColors.success
                                                    : AppColors.textTertiary(context),
                                                border: Border.all(
                                                    color: AppColors.surface(context),
                                                    width: 2,
                                                ),
                                            ),
                                        ),
                                    ),
                                ],
                            ),
                        ),
                        title: Text(
                            widget.coop.coopName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.adaptivePrimary(context),
                            ),
                        ),
                        subtitle: Text(
                            "${widget.coop.coopType.toLowerCase().capitalize()} (${widget.coop.growthPhase.value})",
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                            icon: AnimatedRotation(
                                turns: _isExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 300),
                                child: const Icon(
                                    Icons.expand_more,
                                    size: 40,
                                    color: AppColors.success,
                                ),
                            ),
                            onPressed: () {
                                setState(() {
                                        _isExpanded = !_isExpanded;
                                    });
                            },
                        ),
                    ),

                    // Key metrics visible on collapsed card
                    if (!_isExpanded)
                    Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                                _buildMetricChip(
                                    icon: Icons.egg_outlined,
                                    value: '${widget.coop.numberOfChickens}',
                                    label: 'Birds',
                                    color: AppColors.info,
                                ),
                                _buildMetricChip(
                                    icon: Icons.timer_outlined,
                                    value: widget.coop.chickenAge,
                                    label: 'Age',
                                    color: AppColors.secondaryDark,
                                ),
                                _buildMetricChip(
                                    icon: mortalityPct > 5.0
                                        ? Icons.trending_down_rounded
                                        : Icons.trending_flat_rounded,
                                    value: '${mortalityPct.toStringAsFixed(1)}%',
                                    label: 'Mortality',
                                    color: mortalityColor,
                                ),
                            ],
                        ),
                    ),

                    AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.fastOutSlowIn,
                        child: _isExpanded ? _buildAnimatedExpandedContent() : const SizedBox.shrink(),
                    ),

                    if (!_isExpanded)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 10, right: 10),
                        child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                                children: [
                                  if (widget.coop.coopType == 'LAYERS') ...[
                                    _buildCompactButton(
                                        icon: Icons.monetization_on_outlined,
                                        label: 'Add Sales',
                                        color: AppColors.success,
                                        onTap: () => _showLayersRecordSalesBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                  ] else ...[
                                    _buildCompactButton(
                                        icon: Icons.monetization_on_outlined,
                                        label: 'Add Sales',
                                        color: AppColors.success,
                                        onTap: () => _showBroilerRecordSalesBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                  ],

                                    const SizedBox(width: 8),
                                    _buildCompactButton(
                                        icon: Icons.money_off_csred_outlined,
                                        label: 'Add Expenses',
                                        color: AppColors.secondaryDark,
                                        onTap: () => _showRecordExpenseBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCompactButton(
                                        icon: Icons.heart_broken_outlined,
                                        label: 'Add Mortalities',
                                        color: AppColors.error,
                                        onTap: () => _showRecordMortalityBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                    if (widget.coop.coopType == 'LAYERS') ...[
                                        const SizedBox(width: 8),
                                        _buildCompactButton(
                                            icon: Icons.egg,
                                            label: 'Record Eggs',
                                            color: AppColors.secondaryDark,
                                            onTap: () => _showRecordEggsBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                            context: context,
                                            isActive: widget.coop.active,
                                        ),
                                    ] else ...[
                                        const SizedBox(width: 8),
                                        _buildCompactButton(
                                            icon: Icons.monitor_weight_outlined,
                                            label: 'Weight',
                                            color: AppColors.secondaryDark,
                                            onTap: () => {},
                                            context: context,
                                            isActive: widget.coop.active,
                                        ),
                                    ]
                                ],
                            ),
                        ),
                    ),

                ],
            ),
        ),
        );
    }

    Widget _buildCompactButton({
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
        required BuildContext context,
        required bool isActive,
    }) {
        return SizedBox(
            width: 75,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    elevation: 2,
                    backgroundColor: AppColors.surface(context), // White background
                    foregroundColor: AppColors.adaptivePrimary(context), // Icon & text color
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(20, 36),
                ),
                onPressed: isActive ? onTap : null,
                child: SizedBox(
                    width: 60,
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Icon(
                                icon,
                                size: 18,
                                color: isActive ? color : AppColors.textTertiary(context),
                            ),
                             SizedBox(height: 1),
                            Text(
                                label,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis, // handles long labels
                                style: TextStyle(
                                    color: isActive ? AppColors.adaptivePrimary(context) : AppColors.textTertiary(context),
                                    fontSize: 8,
                                    fontWeight: FontWeight.w400,
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    Widget _buildCompactChip1({
        required IconData icon,
        required String label,
        required Color color,
        required VoidCallback onTap,
        required BuildContext context,
        required bool isActive,
    }) {
        return ActionChip(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            label: SizedBox(
                width: 60,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(
                            icon,
                            size: 18,
                            color: isActive ? color : AppColors.textTertiary(context),
                        ),
                         SizedBox(height: 1),
                        Text(
                            label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis, // handles long labels
                            style: TextStyle(
                                color: isActive ? AppColors.adaptivePrimary(context) : AppColors.textTertiary(context),
                                fontSize: 8,
                                fontWeight: FontWeight.w400,
                            ),
                        ),
                    ],
                ),
            ),
            backgroundColor: AppColors.surface(context),
            side: BorderSide(
                color: isActive
                    ? AppColors.success.withValues(alpha: 0.2)
                    : AppColors.textTertiary(context).withValues(alpha: 0.4),
            ),
            elevation: 0,
            pressElevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onPressed: isActive ? onTap : null,
        );
    }

    // ── Swipe action background ─────────────────────────────────────────────
    Widget _buildSwipeBackground({required bool isRight}) {
        return Container(
            decoration: BoxDecoration(
                color: isRight
                    ? AppColors.success.withOpacity(0.12)
                    : AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
            ),
            alignment: isRight ? Alignment.centerLeft : Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Icon(
                        isRight
                            ? Icons.monetization_on_outlined
                            : Icons.heart_broken_outlined,
                        color: isRight ? AppColors.success : AppColors.error,
                        size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                        isRight ? 'Add Sale' : 'Log Mortality',
                        style: TextStyle(
                            color: isRight ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                        ),
                    ),
                ],
            ),
        );
    }

    // ── Metric chip for the collapsed card ──────────────────────────────────
    Widget _buildMetricChip({
        required IconData icon,
        required String value,
        required String label,
        required Color color,
    }) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.25), width: 0.8),
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                        value,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                        ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                        label,
                        style: TextStyle(
                            fontSize: 10,
                            color: color.withOpacity(0.75),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildAnimatedExpandedContent() {
        return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
                return Opacity(
                    opacity: value,
                    child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                    ),
                );
            },
            child: _buildExpandedSectionContent(),
        );
    }

    Widget _buildExpandedSectionContent() {
        final bool isLayers = widget.coop.coopType == 'LAYERS';
        return Container(
            decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: AppColors.border(context), width: 0.3),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // ── TabBar ──────────────────────────────────────────────
                    TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: AppColors.adaptivePrimary(context),
                        labelColor: AppColors.adaptivePrimary(context),
                        unselectedLabelColor: AppColors.textSecondary(context),
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: const TextStyle(fontSize: 11),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: [
                            const Tab(
                                icon: Icon(Icons.dashboard_outlined, size: 16),
                                text: 'Overview',
                            ),
                            const Tab(
                                icon: Icon(Icons.monetization_on_outlined, size: 16),
                                text: 'Sales',
                            ),
                            const Tab(
                                icon: Icon(Icons.receipt_long_outlined, size: 16),
                                text: 'Expenses',
                            ),
                            const Tab(
                                icon: Icon(Icons.heart_broken_outlined, size: 16),
                                text: 'Mortality',
                            ),
                            if (isLayers)
                                const Tab(
                                    icon: Icon(Icons.egg_outlined, size: 16),
                                    text: 'Eggs',
                                ),
                        ],
                    ),
                    const Divider(height: 1),
                    // ── Tab Content ─────────────────────────────────────────
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                            ),
                            child: _buildTabContent(_currentTab),
                        ),
                    ),
                ],
            ),
        );
    }

    // ── Tab router ─────────────────────────────────────────────────────────
    Widget _buildTabContent(int tabIndex) {
        switch (tabIndex) {
            case 1: return _buildSalesTab();
            case 2: return _buildExpensesTab();
            case 3: return _buildMortalityTab();
            case 4: return _buildEggsTab();
            default: return _buildOverviewTab();
        }
    }

    // ── Tab 0 : Overview ───────────────────────────────────────────────────
    Widget _buildOverviewTab() {
        final int totalMortalities = widget.coop.mortalities
            .fold<int>(0, (sum, m) => sum + m.numberOfDeaths);
        final double mortalityPct =
            (widget.coop.numberOfChickens + totalMortalities) > 0
                ? (totalMortalities /
                    (widget.coop.numberOfChickens + totalMortalities)) * 100
                : 0.0;

        return Column(
            key: const ValueKey('overview'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        // Active / Inactive status pill
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                color: widget.coop.active
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.textTertiary(context)
                                        .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: widget.coop.active
                                                ? AppColors.success
                                                : AppColors.textTertiary(context),
                                        ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                        widget.coop.active ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: widget.coop.active
                                                ? AppColors.success
                                                : AppColors.textTertiary(context),
                                        ),
                                    ),
                                ],
                            ),
                        ),
                        if (widget.user.farmOwner)
                            PopupMenuButton<String>(
                                icon: Icon(
                                    Icons.settings,
                                    color: Theme.of(context).colorScheme.secondary,
                                ),
                                onSelected: (String result) {
                                    _handleMenuSelection(result, widget.coop,
                                        widget.farm.id, widget.onCoopUpdated);
                                },
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                                offset: const Offset(0, 50),
                                color: AppColors.surface(context),
                                elevation: 8,
                                itemBuilder: (BuildContext context) => [
                                    _buildPopupMenuItem(
                                        'updateCoop',
                                        Icons.update,
                                        'Update Coop',
                                        Theme.of(context).colorScheme.secondary),
                                    _buildPopupMenuItem(
                                        'newBatch',
                                        Icons.clear_all_outlined,
                                        'New Chicken batch',
                                        AppColors.warning),
                                    _buildPopupMenuItem(
                                        'deleteCoop',
                                        Icons.delete_outline,
                                        'Delete Coop',
                                        Theme.of(context).colorScheme.error),
                                ],
                            ),
                    ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                    Icons.fact_check_outlined,
                    'Chickens',
                    '${widget.coop.numberOfChickens}',
                ),
                _buildInfoRow(
                    Icons.calendar_today_outlined,
                    'Arrived',
                    widget.coop.chickenArrivalDate,
                ),
                const SizedBox(height: 2),
                _buildInfoRow(
                    Icons.timer_outlined,
                    'Age',
                    widget.coop.chickenAge,
                ),
                const SizedBox(height: 12),
                // Mortality rate summary tile
                Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: mortalityPct > 5
                            ? AppColors.error.withOpacity(0.07)
                            : AppColors.success.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: mortalityPct > 5
                                ? AppColors.error.withOpacity(0.25)
                                : AppColors.success.withOpacity(0.25),
                        ),
                    ),
                    child: Row(
                        children: [
                            Icon(
                                mortalityPct > 5
                                    ? Icons.trending_down_rounded
                                    : Icons.trending_up_rounded,
                                color: mortalityPct > 5
                                    ? AppColors.error
                                    : AppColors.success,
                                size: 22,
                            ),
                            const SizedBox(width: 10),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        'Mortality Rate',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary(context),
                                        ),
                                    ),
                                    Text(
                                        '${mortalityPct.toStringAsFixed(1)}%'
                                        '  ($totalMortalities deaths)',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: mortalityPct > 5
                                                ? AppColors.error
                                                : AppColors.success,
                                        ),
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
            ],
        );
    }

    // ── Tab 1 : Sales ──────────────────────────────────────────────────────
    Widget _buildSalesTab() {
        final sales = widget.coop.sales;
        final double total =
            sales.fold(0.0, (sum, s) => sum + s.totalSaleAmount);

        return Column(
            key: const ValueKey('sales'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                _buildTabSummaryCard(
                    icon: Icons.attach_money,
                    title: 'Total Sales',
                    value: 'R${total.toStringAsFixed(2)}',
                    count: sales.length,
                    colors: [AppColors.success, AppColors.successLight],
                    shadowColor: AppColors.success,
                ),
                const SizedBox(height: 10),
                if (widget.coop.active)
                    _buildAddButton(
                        label: 'Add Sale',
                        color: AppColors.success,
                        onTap: () {
                            if (widget.coop.coopType == 'LAYERS') {
                                _showLayersRecordSalesBottomSheet(
                                    widget.coop,
                                    widget.farm.id,
                                    widget.onCoopUpdated);
                            } else {
                                _showBroilerRecordSalesBottomSheet(
                                    widget.coop,
                                    widget.farm.id,
                                    widget.onCoopUpdated);
                            }
                        },
                    ),
                const SizedBox(height: 8),
                if (sales.isEmpty)
                    _buildEmptyState(
                        'No sales recorded yet',
                        Icons.shopping_cart_outlined,
                    )
                else
                    ...sales.map((s) => _buildInlineSaleItem(s)),
            ],
        );
    }

    // ── Tab 2 : Expenses ────────────────────────────────────────────────────
    Widget _buildExpensesTab() {
        final expenses = widget.coop.expenses;
        final double total = expenses.fold(0.0, (sum, e) => sum + e.amount);

        return Column(
            key: const ValueKey('expenses'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                _buildTabSummaryCard(
                    icon: Icons.receipt_long_outlined,
                    title: 'Total Expenses',
                    value: 'R${total.toStringAsFixed(2)}',
                    count: expenses.length,
                    colors: [AppColors.secondaryDark, AppColors.secondary],
                    shadowColor: AppColors.secondaryDark,
                ),
                const SizedBox(height: 10),
                if (widget.coop.active)
                    _buildAddButton(
                        label: 'Add Expense',
                        color: AppColors.secondaryDark,
                        onTap: () => _showRecordExpenseBottomSheet(
                            widget.coop,
                            widget.farm.id,
                            widget.onCoopUpdated),
                    ),
                const SizedBox(height: 8),
                if (expenses.isEmpty)
                    _buildEmptyState(
                        'No expenses recorded yet',
                        Icons.receipt_long_outlined,
                    )
                else
                    ...expenses.map((e) => _buildInlineExpenseItem(e)),
            ],
        );
    }

    // ── Tab 3 : Mortality ──────────────────────────────────────────────────
    Widget _buildMortalityTab() {
        final mortalities = widget.coop.mortalities;
        final int totalDeaths =
            mortalities.fold<int>(0, (sum, m) => sum + m.numberOfDeaths);

        return Column(
            key: const ValueKey('mortality'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                _buildTabSummaryCard(
                    icon: Icons.heart_broken_outlined,
                    title: 'Total Deaths',
                    value: '$totalDeaths birds',
                    count: mortalities.length,
                    colors: [AppColors.error, AppColors.errorLight],
                    shadowColor: AppColors.error,
                ),
                const SizedBox(height: 10),
                if (widget.coop.active)
                    _buildAddButton(
                        label: 'Log Mortality',
                        color: AppColors.error,
                        onTap: () => _showRecordMortalityBottomSheet(
                            widget.coop,
                            widget.farm.id,
                            widget.onCoopUpdated),
                    ),
                const SizedBox(height: 8),
                if (mortalities.isEmpty)
                    _buildEmptyState(
                        'No mortality recorded yet',
                        Icons.pets_outlined,
                    )
                else
                    ...mortalities.map((m) => _buildInlineMortalityItem(m)),
            ],
        );
    }

    // ── Tab 4 : Egg Packaging (LAYERS only) ───────────────────────────────
    Widget _buildEggsTab() {
        final records = widget.coop.eggPackagingRecords;
        final int totalEggs =
            records.fold<int>(0, (sum, r) => sum + r.totalEggs);

        return Column(
            key: const ValueKey('eggs'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                _buildTabSummaryCard(
                    icon: Icons.egg_outlined,
                    title: 'Total Eggs Packed',
                    value: '$totalEggs eggs',
                    count: records.length,
                    colors: [AppColors.warning, AppColors.warningLight],
                    shadowColor: AppColors.warning,
                ),
                const SizedBox(height: 10),
                if (widget.coop.active)
                    _buildAddButton(
                        label: 'Record Eggs',
                        color: AppColors.warning,
                        onTap: () => _showRecordEggsBottomSheet(
                            widget.coop,
                            widget.farm.id,
                            widget.onCoopUpdated),
                    ),
                const SizedBox(height: 8),
                if (records.isEmpty)
                    _buildEmptyState(
                        'No egg packaging records yet',
                        Icons.egg_outlined,
                    )
                else
                    ...records.map((r) => _buildInlineEggItem(r)),
            ],
        );
    }

    // ── Shared tab summary card ─────────────────────────────────────────────
    Widget _buildTabSummaryCard({
        required IconData icon,
        required String title,
        required String value,
        required int count,
        required List<Color> colors,
        required Color shadowColor,
    }) {
        return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                    BoxShadow(
                        color: shadowColor.withOpacity(0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                    ),
                ],
            ),
            child: Row(
                children: [
                    Icon(icon, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(
                                title,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                ),
                            ),
                            TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: 1),
                                duration: const Duration(milliseconds: 600),
                                builder: (context, val, _) => Opacity(
                                    opacity: val,
                                    child: Text(
                                        value,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    ),
                    const Spacer(),
                    Text(
                        '$count record${count == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                        ),
                    ),
                ],
            ),
        );
    }

    // ── Add button ──────────────────────────────────────────────────────────
    Widget _buildAddButton({
        required String label,
        required Color color,
        required VoidCallback onTap,
    }) {
        return SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onTap,
            ),
        );
    }

    // ── Empty state ─────────────────────────────────────────────────────────
    Widget _buildEmptyState(String message, IconData icon) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.surfaceVariant(context),
                            ),
                            child: Icon(
                                icon,
                                size: 34,
                                color: AppColors.textTertiary(context),
                            ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                            message,
                            style: TextStyle(
                                color: AppColors.textSecondary(context),
                                fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                        ),
                    ],
                ),
            ),
        );
    }

    // ── Inline sale item ────────────────────────────────────────────────────
    Widget _buildInlineSaleItem(Sale sale) {
        final saleDate = DateFormat('MMM d, yyyy')
            .format(DateTime.parse(sale.saleDate));
        final isPaid = sale.paymentStatus == 'PAID';

        return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            color: AppColors.surfaceVariant(context),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.success.withOpacity(0.15),
                    child: const Icon(
                        Icons.shopping_cart_outlined,
                        size: 16,
                        color: AppColors.success,
                    ),
                ),
                title: Text(
                    sale.buyerName,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                    ),
                ),
                subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(
                            'R${sale.totalSaleAmount.toStringAsFixed(2)} · $saleDate',
                            style: const TextStyle(fontSize: 11),
                        ),
                        const SizedBox(height: 2),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                                color: isPaid
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                                sale.paymentStatus,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: isPaid
                                        ? AppColors.success
                                        : AppColors.warning,
                                ),
                            ),
                        ),
                    ],
                ),
                trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        IconButton(
                            icon: const Icon(
                                Icons.info_outline,
                                size: 17,
                                color: AppColors.info,
                            ),
                            onPressed: () =>
                                _showSaleDetailsDialog(context, sale),
                            constraints:
                                const BoxConstraints.tightFor(width: 32, height: 32),
                            padding: EdgeInsets.zero,
                        ),
                        IconButton(
                            icon: const Icon(
                                Icons.delete_outline,
                                size: 17,
                                color: AppColors.error,
                            ),
                            onPressed: () => _deleteCoopItemDialog(
                                'Sale',
                                sale.id,
                                widget.user.id,
                                widget.farm.id,
                                widget.coop.id,
                                widget.onCoopUpdated,
                            ),
                            constraints:
                                const BoxConstraints.tightFor(width: 32, height: 32),
                            padding: EdgeInsets.zero,
                        ),
                    ],
                ),
            ),
        );
    }

    // ── Inline expense item ─────────────────────────────────────────────────
    Widget _buildInlineExpenseItem(Expense expense) {
        final expenseDate = DateFormat('MMM d, yyyy')
            .format(DateTime.parse(expense.expenseDate));

        return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            color: AppColors.surfaceVariant(context),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.secondaryDark.withOpacity(0.15),
                    child: const Icon(
                        Icons.receipt_long_outlined,
                        size: 16,
                        color: AppColors.secondaryDark,
                    ),
                ),
                title: Text(
                    expense.expenseType,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                    ),
                ),
                subtitle: Text(
                    'R${expense.amount.toStringAsFixed(2)} · $expenseDate',
                    style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                    icon: const Icon(
                        Icons.delete_outline,
                        size: 17,
                        color: AppColors.error,
                    ),
                    onPressed: () => _deleteCoopItemDialog(
                        'Expense',
                        expense.id,
                        widget.user.id,
                        widget.farm.id,
                        widget.coop.id,
                        widget.onCoopUpdated,
                    ),
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    padding: EdgeInsets.zero,
                ),
            ),
        );
    }

    // ── Inline mortality item ───────────────────────────────────────────────
    Widget _buildInlineMortalityItem(Mortality mortality) {
        final dateOccurred = DateFormat('MMM d, yyyy')
            .format(DateTime.parse(mortality.dateOccurred));

        return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            color: AppColors.surfaceVariant(context),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.error.withOpacity(0.15),
                    child: const Icon(
                        Icons.heart_broken_outlined,
                        size: 16,
                        color: AppColors.error,
                    ),
                ),
                title: Text(
                    '${mortality.numberOfDeaths} birds · $dateOccurred',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                    ),
                ),
                subtitle: Text(
                    mortality.reason,
                    style: const TextStyle(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                    icon: const Icon(
                        Icons.delete_outline,
                        size: 17,
                        color: AppColors.error,
                    ),
                    onPressed: () => _deleteCoopItemDialog(
                        'Mortality',
                        mortality.id,
                        widget.user.id,
                        widget.farm.id,
                        widget.coop.id,
                        widget.onCoopUpdated,
                    ),
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    padding: EdgeInsets.zero,
                ),
            ),
        );
    }

    // ── Inline egg packaging item ───────────────────────────────────────────
    Widget _buildInlineEggItem(EggPackagingRecord record) {
        final recordDate = DateFormat('MMM d, yyyy')
            .format(DateTime.parse(record.createdDate));

        return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            color: AppColors.surfaceVariant(context),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.warning.withOpacity(0.15),
                    child: const Icon(
                        Icons.egg_outlined,
                        size: 16,
                        color: AppColors.warning,
                    ),
                ),
                title: Text(
                    '${record.totalEggs} eggs · ${record.eggSize}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                    ),
                ),
                subtitle: Text(
                    '${record.numberOfBoxes} ${record.boxSize} boxes · $recordDate',
                    style: const TextStyle(fontSize: 11),
                ),
                trailing: IconButton(
                    icon: const Icon(
                        Icons.delete_outline,
                        size: 17,
                        color: AppColors.error,
                    ),
                    onPressed: () => _deleteCoopItemDialog(
                        'EggPackagingRecord',
                        record.id,
                        widget.user.id,
                        widget.farm.id,
                        widget.coop.id,
                        widget.onCoopUpdated,
                    ),
                    constraints:
                        const BoxConstraints.tightFor(width: 32, height: 32),
                    padding: EdgeInsets.zero,
                ),
            ),
        );
    }

    Widget _buildSalesCardSection({
        required List<Sale> sales,
        required String userId,
        required String farmId,
        required String coopId,
        required VoidCallback onCoopDeleted,
        required BuildContext context,
    }) {
        // Calculate the total sale amount
        double totalSaleAmount =
            sales.fold(0, (sum, sale) => sum + sale.totalSaleAmount);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    splashColor: AppColors.success.withOpacity(0.2),
                    onTap: () {
                        _showSalesBottomSheet(
                            context,
                            sales,
                            userId,
                            farmId,
                            coopId,
                            onCoopDeleted,
                        );
                    },
                    child: Container(
                        padding:  EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                            color: AppColors.textTertiary(context).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                                BoxShadow(
                                    color: AppColors.textTertiary(context).withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                ),
                            ],
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                // Title on the left
                                Text(
                                    "Sales",
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                    ),
                                ),

                                // Right side: badge + arrow
                                Row(
                                    children: [
                                        // Badge with min size
                                        Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 60,  // keeps it consistent
                                                minHeight: 28,
                                            ),
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                            decoration: BoxDecoration(
                                                color: AppColors.successLight,
                                                borderRadius: BorderRadius.circular(12.0),
                                            ),
                                            child: Text(
                                                'R${totalSaleAmount.toStringAsFixed(2)}',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.success,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Arrow at the very end
                                        const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: AppColors.success,
                                        ),
                                    ],
                                ),
                            ],
                        ),

                    ),
                ),
            ],
        );
    }

    /// BottomSheet for displaying sales
    void _showSalesBottomSheet(
        BuildContext context,
        List<Sale> sales,
        String userId,
        String farmId,
        String coopId,
        VoidCallback onCoopDeleted,
    ) {
        // Make a local copy of sales to allow live updates
        List<Sale> currentSales = List.from(sales);

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return StatefulBuilder(
                    builder: (context, setState) {
                        // Recalculate totalSaleAmount whenever the list changes
                        double totalSaleAmount =
                            currentSales.fold(0, (sum, sale) => sum + sale.totalSaleAmount);

                        return DraggableScrollableSheet(
                            expand: false,
                            initialChildSize: 0.7,
                            minChildSize: 0.4,
                            maxChildSize: 0.95,
                            builder: (context, scrollController) {
                                return Column(
                                    children: [
                                        // Header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.3),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                    // Centered title
                                                    Center(
                                                        child: Text(
                                                            'Sales',
                                                            style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.adaptivePrimary(context),
                                                                letterSpacing: 0.5,
                                                            ),
                                                        ),
                                                    ),

                                                    // Close button aligned to the right
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: Icon(Icons.close, color: AppColors.textTertiary(context)),
                                                            onPressed: () {
                                                                Navigator.of(context).pop(); // closes the bottom sheet
                                                            },
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),

                                        const Divider(height: 1),

                                        // 👇 Total Sales Card with animated total
                                        Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        colors: [AppColors.success, AppColors.successLight],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: AppColors.success.withOpacity(0.4),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    children: [
                                                        // Money Icon
                                                        Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration:  BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child:  Icon(
                                                                Icons.attach_money,
                                                                size: 32,
                                                                color: AppColors.surface(context),
                                                            ),
                                                        ),
                                                        const SizedBox(width: 16),

                                                        // Texts
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                const Text(
                                                                    'Total Sales',
                                                                    style: TextStyle(
                                                                        fontSize: 16,
                                                                        color: Colors.white70,
                                                                        fontWeight: FontWeight.w500,
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 4),

                                                                // Animated total amount
                                                                TweenAnimationBuilder<double>(
                                                                    tween: Tween<double>(begin: 0, end: totalSaleAmount),
                                                                    duration:  Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            'R${value.toStringAsFixed(2)}',
                                                                            style: TextStyle(
                                                                                fontSize: 24,
                                                                                color: AppColors.surface(context),
                                                                                fontWeight: FontWeight.bold,
                                                                            ),
                                                                        );
                                                                    },
                                                                ),
                                                            ],
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),

                                        // Scrollable sales list
                                        Expanded(
                                            child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                child: currentSales.isNotEmpty
                                                    ? ListView.builder(
                                                        controller: scrollController,
                                                        itemCount: currentSales.length,
                                                        itemBuilder: (context, index) {
                                                            final sale = currentSales[index];
                                                            final saleDate = DateFormat('yyyy-MM-dd')
                                                                .format(DateTime.parse(sale.saleDate));

                                                            return Card(
                                                                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                                                elevation: 3.0,
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(12.0),
                                                                ),
                                                                child: ListTile(
                                                                    leading: CircleAvatar(
                                                                        backgroundColor: AppColors.success.withOpacity(0.2),
                                                                        child: const Icon(Icons.shopping_cart, color: AppColors.success),
                                                                    ),
                                                                    title: Text(
                                                                        sale.buyerName,
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .bodySmall
                                                                            ?.copyWith(fontWeight: FontWeight.bold),
                                                                    ),
                                                                    subtitle: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            Text('Total: R${sale.totalSaleAmount}',
                                                                                style: Theme.of(context).textTheme.bodySmall),
                                                                            Text('Date: $saleDate',
                                                                                style: TextStyle(fontSize: 10.0, color: AppColors.textSecondary(context))),
                                                                        ],
                                                                    ),
                                                                    trailing: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                            IconButton(
                                                                                icon: const Icon(Icons.info_outline, color: AppColors.info),
                                                                                onPressed: () {
                                                                                    _showSaleDetailsDialog(context, sale);
                                                                                },
                                                                            ),
                                                                            IconButton(
                                                                                icon: const Icon(Icons.delete, color: AppColors.error),
                                                                                onPressed: () {
                                                                                    _deleteCoopItemDialog(
                                                                                        'Sale',
                                                                                        sale.id,
                                                                                        userId,
                                                                                        farmId,
                                                                                        coopId,
                                                                                        () {
                                                                                            // Remove deleted sale from local list and refresh
                                                                                            setState(() {
                                                                                                    currentSales.removeWhere((s) => s.id == sale.id);
                                                                                                });

                                                                                            // Also call parent callback
                                                                                            onCoopDeleted();
                                                                                        },
                                                                                    );
                                                                                },
                                                                            ),
                                                                        ],
                                                                    ),
                                                                ),
                                                            );
                                                        },
                                                    )
                                                    : Center(
                                                        child: Padding(
                                                            padding:  EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No sales recorded yet.',
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(color: AppColors.textSecondary(context)),
                                                            ),
                                                        ),
                                                    ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );
    }

    Widget _buildMortalityCardSection({
        required List<Mortality> mortalities,
        required String userId,
        required String farmId,
        required String coopId,
        required VoidCallback onCoopDeleted,
        required BuildContext context,
    }) {
        int totalMortalities = mortalities.fold<int>(
            0, (sum, mortality) => sum + mortality.numberOfDeaths);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    splashColor: AppColors.error.withOpacity(0.2),
                    onTap: () {
                        _showMortalityBottomSheet(
                            context, mortalities, userId, farmId, coopId, onCoopDeleted);
                    },
                    child: Container(
                        padding:  EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                            color: AppColors.textTertiary(context).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                                BoxShadow(
                                    color: AppColors.textTertiary(context).withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                ),
                            ],
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                // Title on the left
                                Text(
                                    "Mortalities",
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                    ),
                                ),

                                // Right side: badge + arrow
                                Row(
                                    children: [
                                        // Badge with min size
                                        Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 60,
                                                minHeight: 28,
                                            ),
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                            decoration: BoxDecoration(
                                                color: AppColors.warningLight,
                                                borderRadius: BorderRadius.circular(12.0),
                                            ),
                                            child: Text(
                                                totalMortalities.toString(),
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.warning,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Arrow at the very end
                                        const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: AppColors.success,
                                        ),
                                    ],
                                ),
                            ],
                        ),

                    ),
                ),
            ],
        );
    }

    void _showMortalityBottomSheet(
        BuildContext context,
        List<Mortality> mortalities,
        String userId,
        String farmId,
        String coopId,
        VoidCallback onCoopDeleted,
    ) {
        int totalMortalities =
            mortalities.fold<int>(0, (sum, mortality) => sum + mortality.numberOfDeaths);

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return StatefulBuilder(builder: (context, setState) {
                        return DraggableScrollableSheet(
                            expand: false,
                            initialChildSize: 0.7,
                            minChildSize: 0.4,
                            maxChildSize: 0.95,
                            builder: (context, scrollController) {
                                return Column(
                                    children: [
                                        // Header with close icon
                                        Container(
                                            padding:
                                            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.3),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                    Center(
                                                        child: Text(
                                                            'Mortalities',
                                                            style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.adaptivePrimary(context),
                                                                letterSpacing: 0.5,
                                                            ),
                                                        ),
                                                    ),
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: Icon(Icons.close, color: AppColors.textTertiary(context)),
                                                            onPressed: () => Navigator.of(context).pop(),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Total Mortalities Card
                                        Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        colors: [AppColors.error, AppColors.error],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: AppColors.error.withOpacity(0.4),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration:  BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child:  Icon(
                                                                Icons.block,
                                                                size: 32,
                                                                color: AppColors.surface(context),
                                                            ),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                const Text(
                                                                    'Total Mortalities',
                                                                    style: TextStyle(
                                                                        fontSize: 16,
                                                                        color: Colors.white70,
                                                                        fontWeight: FontWeight.w500,
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                TweenAnimationBuilder<double>(
                                                                    tween: Tween<double>(
                                                                        begin: 0, end: totalMortalities.toDouble()),
                                                                    duration:  Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            value.toStringAsFixed(0),
                                                                            style: TextStyle(
                                                                                fontSize: 24,
                                                                                color: AppColors.surface(context),
                                                                                fontWeight: FontWeight.bold,
                                                                            ),
                                                                        );
                                                                    },
                                                                ),
                                                            ],
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),

                                        // Scrollable list of mortalities
                                        Expanded(
                                            child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                child: mortalities.isNotEmpty
                                                    ? ListView.builder(
                                                        controller: scrollController,
                                                        itemCount: mortalities.length,
                                                        itemBuilder: (context, index) {
                                                            final mortality = mortalities[index];
                                                            final dateOccurred = DateFormat('yyyy-MM-dd')
                                                                .format(DateTime.parse(mortality.dateOccurred));

                                                            return Card(
                                                                margin: const EdgeInsets.symmetric(
                                                                    vertical: 8.0, horizontal: 4.0),
                                                                elevation: 3.0,
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(12.0),
                                                                ),
                                                                child: ListTile(
                                                                    leading: CircleAvatar(
                                                                        backgroundColor: AppColors.error.withOpacity(0.2),
                                                                        child: const Icon(Icons.block_outlined,
                                                                            color: AppColors.error),
                                                                    ),
                                                                    title: Text(
                                                                        mortality.reason,
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .bodySmall
                                                                            ?.copyWith(fontWeight: FontWeight.bold),
                                                                    ),
                                                                    subtitle: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            Text(
                                                                                'Number Of Deaths: ${mortality.numberOfDeaths}',
                                                                                style: Theme.of(context)
                                                                                    .textTheme
                                                                                    .bodySmall),
                                                                            Text('Date Occurred: $dateOccurred',
                                                                                style: TextStyle(
                                                                                    fontSize: 10.0,
                                                                                    color: AppColors.textSecondary(context))),
                                                                        ],
                                                                    ),
                                                                    trailing: IconButton(
                                                                        icon: const Icon(Icons.delete, color: AppColors.error),
                                                                        onPressed: () async {
                                                                            _deleteCoopItemDialog(
                                                                                'Mortality',
                                                                                mortality.id,
                                                                                userId,
                                                                                farmId,
                                                                                coopId,
                                                                                () {
                                                                                    setState(() {
                                                                                            mortalities.removeAt(index);
                                                                                            totalMortalities = mortalities.fold<int>(
                                                                                                0, (sum, m) => sum + m.numberOfDeaths);
                                                                                        });

                                                                                    // Also call parent callback
                                                                                    onCoopDeleted();
                                                                                },
                                                                            );
                                                                        },
                                                                    ),
                                                                ),
                                                            );
                                                        },
                                                    )
                                                    : Center(
                                                        child: Padding(
                                                            padding:  EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No mortality recorded yet.',
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(color: AppColors.textSecondary(context)),
                                                            ),
                                                        ),
                                                    ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    });
            },
        );
    }

    Widget _buildExpenseCardSection({
        required List<Expense> expenses,
        required String userId,
        required String farmId,
        required String coopId,
        required VoidCallback onCoopDeleted,
        required BuildContext context,
    }) {
        double totalExpenses = expenses.fold(0, (sum, expense) => sum + expense.amount);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                InkWell(
                    borderRadius: BorderRadius.circular(12.0),
                    splashColor: AppColors.secondary.withOpacity(0.2),
                    onTap: () {
                        _showExpensesBottomSheet(
                            context,
                            expenses,
                            userId,
                            farmId,
                            coopId,
                            onCoopDeleted,
                        );
                    },
                    child: Container(
                        padding:  EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                            color: AppColors.textTertiary(context).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                                BoxShadow(
                                    color: AppColors.textTertiary(context).withOpacity(0.2),
                                    spreadRadius: 1,
                                    blurRadius: 5,
                                    offset: const Offset(0, 2),
                                ),
                            ],
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                // Title on the left
                                Text(
                                    "Expenses",
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondaryDark,
                                    ),
                                ),

                                // Right side: badge + arrow
                                Row(
                                    children: [
                                        // Badge with min size
                                        Container(
                                            constraints: const BoxConstraints(
                                                minWidth: 60,
                                                minHeight: 28,
                                            ),
                                            alignment: Alignment.center,
                                            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                            decoration: BoxDecoration(
                                                color: AppColors.secondaryLight,
                                                borderRadius: BorderRadius.circular(12.0),
                                            ),
                                            child: Text(
                                                'R${totalExpenses.toStringAsFixed(2)}',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.secondary,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Arrow at the very end
                                        const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: AppColors.success,
                                        ),
                                    ],
                                ),
                            ],
                        ),

                    ),
                ),
            ],
        );
    }

    void _showExpensesBottomSheet(
        BuildContext context,
        List<Expense> expenses,
        String userId,
        String farmId,
        String coopId,
        VoidCallback onCoopDeleted,
    ) {
        double totalExpenses = expenses.fold(0, (sum, expense) => sum + expense.amount);

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                // Use StatefulBuilder to rebuild inside the sheet
                return StatefulBuilder(builder: (context, setState) {
                        return DraggableScrollableSheet(
                            expand: false,
                            initialChildSize: 0.7,
                            minChildSize: 0.4,
                            maxChildSize: 0.95,
                            builder: (context, scrollController) {
                                return Column(
                                    children: [
                                        // Header with close icon
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.3),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                    Center(
                                                        child: Text(
                                                            'Expenses',
                                                            style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.adaptivePrimary(context),
                                                                letterSpacing: 0.5,
                                                            ),
                                                        ),
                                                    ),
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: Icon(Icons.close, color: AppColors.textTertiary(context)),
                                                            onPressed: () => Navigator.of(context).pop(),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Total Expenses Card with animation
                                        Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                        colors: [AppColors.secondaryDark, AppColors.secondaryLight],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: AppColors.secondary.withOpacity(0.4),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration:  BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child:  Icon(
                                                                Icons.monetization_on,
                                                                size: 32,
                                                                color: AppColors.surface(context),
                                                            ),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                const Text(
                                                                    'Total Expenses',
                                                                    style: TextStyle(
                                                                        fontSize: 16,
                                                                        color: Colors.white70,
                                                                        fontWeight: FontWeight.w500,
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                TweenAnimationBuilder<double>(
                                                                    tween: Tween<double>(begin: 0, end: totalExpenses),
                                                                    duration:  Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            'R${value.toStringAsFixed(2)}',
                                                                            style: TextStyle(
                                                                                fontSize: 24,
                                                                                color: AppColors.surface(context),
                                                                                fontWeight: FontWeight.bold,
                                                                            ),
                                                                        );
                                                                    },
                                                                ),
                                                            ],
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),

                                        // Scrollable list of expenses
                                        Expanded(
                                            child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                child: expenses.isNotEmpty
                                                    ? ListView.builder(
                                                        controller: scrollController,
                                                        itemCount: expenses.length,
                                                        itemBuilder: (context, index) {
                                                            final expense = expenses[index];
                                                            final expenseDate = DateFormat('yyyy-MM-dd')
                                                                .format(DateTime.parse(expense.expenseDate));

                                                            return Card(
                                                                margin: const EdgeInsets.symmetric(
                                                                    vertical: 8.0, horizontal: 4.0),
                                                                elevation: 3.0,
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(12.0),
                                                                ),
                                                                child: ListTile(
                                                                    leading: CircleAvatar(
                                                                        backgroundColor: AppColors.secondary.withOpacity(0.2),
                                                                        child: const Icon(Icons.monetization_on,
                                                                            color: AppColors.secondary),
                                                                    ),
                                                                    title: Text(
                                                                        expense.expenseType,
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .bodySmall
                                                                            ?.copyWith(fontWeight: FontWeight.bold),
                                                                    ),
                                                                    subtitle: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            Text('Amount: R${expense.amount}',
                                                                                style:
                                                                                Theme.of(context).textTheme.bodySmall),
                                                                            Text('Expense Date: $expenseDate',
                                                                                style: TextStyle(
                                                                                    fontSize: 10.0,
                                                                                    color: AppColors.textSecondary(context))),
                                                                            if (expense.additionalInfo.trim().isNotEmpty)
                                                                            Text(
                                                                                'Additional Info: ${expense.additionalInfo}',
                                                                                style: TextStyle(
                                                                                    fontSize: 10.0, color: AppColors.textSecondary(context)),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                    trailing: IconButton(
                                                                        icon: const Icon(Icons.delete, color: AppColors.error),
                                                                        onPressed: () async {
                                                                            _deleteCoopItemDialog(
                                                                                'Expense',
                                                                                expense.id,
                                                                                userId,
                                                                                farmId,
                                                                                coopId,
                                                                                () {
                                                                                    setState(() {
                                                                                            expenses.removeAt(index);
                                                                                            totalExpenses = expenses.fold(
                                                                                                0, (sum, e) => sum + e.amount);
                                                                                        });

                                                                                    // Also call parent callback
                                                                                    onCoopDeleted();
                                                                                },
                                                                            );
                                                                        },
                                                                    ),
                                                                ),
                                                            );
                                                        },
                                                    )
                                                    : Center(
                                                        child: Padding(
                                                            padding:  EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No expenses recorded yet.',
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(color: AppColors.textSecondary(context)),
                                                            ),
                                                        ),
                                                    ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    });
            },
        );
    }

    Widget _buildEggsRecordCardSection({
        required List<EggPackagingRecord> eggPackagingRecords,
        required String userId,
        required String farmId,
        required String coopId,
        required VoidCallback onCoopDeleted,
        required BuildContext context,
    }) {
        // Calculate total eggs
        int totalEggs = eggPackagingRecords.fold(0, (sum, record) => sum + record.totalEggs);

        return InkWell(
            borderRadius: BorderRadius.circular(12.0),
            splashColor: AppColors.warning.withOpacity(0.2),
            onTap: () {
                _showEggPackagingRecordsBottomSheet(
                    context,
                    eggPackagingRecords,
                    userId,
                    farmId,
                    coopId,
                    onCoopDeleted,
                );
            },
            child: Container(
                padding:  EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                    color: AppColors.textTertiary(context).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                        BoxShadow(
                            color: AppColors.textTertiary(context).withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                        ),
                    ],
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        // Title on the left
                        Text(
                            "Eggs Packaging",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondaryDark,
                            ),
                        ),

                        // Right side: badge + arrow
                        Row(
                            children: [
                                // Badge with min size
                                Container(
                                    constraints:  BoxConstraints(
                                        minWidth: 60,
                                        minHeight: 28,
                                    ),
                                    alignment: Alignment.center,
                                    padding:  EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                    decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant(context),
                                        borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Text(
                                        totalEggs.toString(),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.secondaryDark,
                                        ),
                                    ),
                                ),
                                const SizedBox(width: 8),

                                // Arrow at the very end
                                const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 18,
                                    color: AppColors.success,
                                ),
                            ],
                        ),
                    ],
                ),

            ),
        );
    }

    void _showEggPackagingRecordsBottomSheet(
        BuildContext context,
        List<EggPackagingRecord> eggPackagingRecords,
        String userId,
        String farmId,
        String coopId,
        VoidCallback onCoopDeleted,
    ) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.7,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {
                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                int totalEggs = eggPackagingRecords.fold(0, (sum, record) => sum + record.totalEggs);

                                return Column(
                                    children: [
                                        // Header with close button
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.3),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                    Center(
                                                        child: Text(
                                                            'Egg Packaging Records',
                                                            style: TextStyle(
                                                                fontSize: 20,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.adaptivePrimary(context),
                                                            ),
                                                        ),
                                                    ),
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: Icon(Icons.close, color: AppColors.textTertiary(context)),
                                                            onPressed: () {
                                                                Navigator.of(context).pop();
                                                            },
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Total eggs card
                                        Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.all(20),
                                                decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                        colors: [AppColors.secondaryDark, Color(
                                                                0xFFEAD47E)],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: AppColors.warning.withOpacity(0.4),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration:  BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child:  Icon(
                                                                Icons.egg,
                                                                size: 32,
                                                                color: AppColors.surface(context),
                                                            ),
                                                        ),
                                                        const SizedBox(width: 16),
                                                        Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                const Text(
                                                                    'Total Eggs',
                                                                    style: TextStyle(
                                                                        fontSize: 16,
                                                                        color: Colors.white70,
                                                                        fontWeight: FontWeight.w500,
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                TweenAnimationBuilder<double>(
                                                                    tween: Tween<double>(begin: 0, end: totalEggs.toDouble()),
                                                                    duration:  Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            value.toStringAsFixed(0),
                                                                            style: TextStyle(
                                                                                fontSize: 24,
                                                                                color: AppColors.surface(context),
                                                                                fontWeight: FontWeight.bold,
                                                                            ),
                                                                        );
                                                                    },
                                                                ),
                                                            ],
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),

                                        // Scrollable list of egg records
                                        Expanded(
                                            child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                child: eggPackagingRecords.isNotEmpty
                                                    ? ListView.builder(
                                                        controller: scrollController,
                                                        itemCount: eggPackagingRecords.length,
                                                        itemBuilder: (context, index) {
                                                            final record = eggPackagingRecords[index];
                                                            final createdDate =
                                                                DateFormat('yyyy-MM-dd').format(DateTime.parse(record.createdDate));

                                                            return Card(
                                                                margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                                                elevation: 3.0,
                                                                shape: RoundedRectangleBorder(
                                                                    borderRadius: BorderRadius.circular(12.0),
                                                                ),
                                                                child: ListTile(
                                                                    leading: CircleAvatar(
                                                                        backgroundColor: AppColors.warning.withOpacity(0.2),
                                                                        child: const Icon(Icons.egg, color: AppColors.warning),
                                                                    ),
                                                                    title: Text(
                                                                        '${record.eggSize} Eggs - ${record.boxSize}',
                                                                        style: Theme.of(context)
                                                                            .textTheme
                                                                            .titleSmall
                                                                            ?.copyWith(fontWeight: FontWeight.bold),
                                                                    ),
                                                                    subtitle: Column(
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                            Row(
                                                                                children: [
                                                                                    const Icon(Icons.inventory_2_outlined, size: 12,),
                                                                                    const SizedBox(width: 6),
                                                                                    Text(
                                                                                        'Number of Boxes: ${record.numberOfBoxes}',
                                                                                        style: Theme.of(context)
                                                                                            .textTheme
                                                                                            .labelSmall
                                                                                            ?.copyWith(fontWeight: FontWeight.normal,),
                                                                                    ),
                                                                                ],
                                                                            ),
                                                                            const SizedBox(height: 4),
                                                                            Row(
                                                                                children: [
                                                                                    const Icon(Icons.egg_outlined, size: 14, ),
                                                                                    const SizedBox(width: 4),
                                                                                    Text(
                                                                                        'Total Eggs: ${record.totalEggs}',
                                                                                        style: Theme.of(context)
                                                                                            .textTheme
                                                                                            .labelSmall
                                                                                            ?.copyWith(fontWeight: FontWeight.normal,),
                                                                                    ),
                                                                                ],
                                                                            ),
                                                                            const SizedBox(height: 4),
                                                                            Row(
                                                                                children: [
                                                                                    const Icon(Icons.calendar_today, size: 12),
                                                                                    const SizedBox(width: 6),
                                                                                    Text(
                                                                                        'Date: $createdDate',
                                                                                        style: Theme.of(context)
                                                                                            .textTheme
                                                                                            .labelSmall
                                                                                            ?.copyWith(fontWeight: FontWeight.normal,),
                                                                                    ),
                                                                                ],
                                                                            ),
                                                                            if (record.additionalInfo.trim().isNotEmpty) ...[
                                                                                const SizedBox(height: 4),
                                                                                Row(
                                                                                    children: [
                                                                                        const Icon(Icons.info_outline, size: 12),
                                                                                        const SizedBox(width: 6),
                                                                                        Expanded(
                                                                                            child: Text(
                                                                                                'Info: ${record.additionalInfo}',
                                                                                                style: Theme.of(context)
                                                                                                    .textTheme
                                                                                                    .labelSmall
                                                                                                    ?.copyWith(fontWeight: FontWeight.normal,),
                                                                                            ),
                                                                                        ),
                                                                                    ],
                                                                                ),
                                                                            ],
                                                                        ],
                                                                    ),

                                                                    trailing: IconButton(
                                                                        icon: const Icon(Icons.delete, color: AppColors.error),
                                                                        onPressed: () async {
                                                                            _deleteCoopItemDialog(
                                                                                'Egg Packaging Record',
                                                                                record.id,
                                                                                userId,
                                                                                farmId,
                                                                                coopId,
                                                                                () {
                                                                                    // Remove the record from the list
                                                                                    setModalState(() {
                                                                                        eggPackagingRecords.removeWhere((r) => r.id == record.id);
                                                                                    });
                                                                                    // Also call the parent callback to update the main UI
                                                                                    onCoopDeleted();
                                                                                },
                                                                            );
                                                                        },
                                                                    ),

                                                                ),
                                                            );
                                                        },
                                                    )
                                                    : Center(
                                                        child: Padding(
                                                            padding:  EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No egg packaging records yet.',
                                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                                    color: AppColors.textSecondary(context),
                                                                ),
                                                            ),
                                                        ),
                                                    ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );
    }

    void _deleteCoopItemDialog(String itemType, String id, String userId,
        String farmId, String coopId, VoidCallback onCoopDeleted) {
        String title = 'Delete $itemType';
        String itemTypeLowerCase = itemType.toLowerCase();
        String content =
            'Are you sure you want to delete this $itemTypeLowerCase? This action cannot be undone.';

        showDialog(
            context: context,
            builder: (BuildContext context) {
                return AlertDialog(
                    title: Text(title),
                    content: Text(content),
                    actions: <Widget>[
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.adaptivePrimary(context),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                                Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                        ),
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.warning,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {

                                await Common.showLottieDialog(
                                    context,
                                    lottiePath: 'assets/lottie/loading_animation.json',
                                );

                                final MessageResponse response = await service.deleteCoopItem(
                                    deletedByUserId: userId,
                                    farmId: farmId,
                                    coopId: coopId,
                                    itemId: id,
                                    itemType: itemType);

                                if (response.success) {

                                    await Common.showLottieDialog(
                                        context,
                                        lottiePath: 'assets/lottie/success_check.json',
                                        autoCloseAfter: const Duration(seconds: 2),
                                    );
                                    onCoopDeleted();
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();

                                } else {
                                    await Common.showLottieDialog(
                                        context,
                                        lottiePath: 'assets/lottie/error.json',
                                        message: response.message,
                                        autoCloseAfter: const Duration(seconds: 5),
                                    );
                                    Navigator.of(context).pop();
                                    Navigator.of(context).pop();
                                }
                            },
                            child: const Text('Confirm'),
                        ),
                    ],
                );
            },
        );
    }

    void _showSaleDetailsDialog(BuildContext context, Sale sale) {
        final saleDate = DateFormat('MMM d, yyyy').format(DateTime.parse(sale.saleDate));
        final isPaid = sale.paymentStatus.toUpperCase() == 'PAID';

        showDialog(
            context: context,
            builder: (context) {
                return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                // ── Gradient header ───────────────────────────
                                Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                                    decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [AppColors.success, AppColors.successLight],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                        ),
                                    ),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            // Title row + close
                                            Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                    Row(children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(7),
                                                            decoration: BoxDecoration(
                                                                color: Colors.white.withValues(alpha: 0.25),
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.receipt_long_rounded,
                                                                color: Colors.white, size: 18),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        const Text(
                                                            'Sale Details',
                                                            style: TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 17,
                                                                fontWeight: FontWeight.w700,
                                                                letterSpacing: 0.3,
                                                            ),
                                                        ),
                                                    ]),
                                                    GestureDetector(
                                                        onTap: () => Navigator.of(context).pop(),
                                                        child: Container(
                                                            padding: const EdgeInsets.all(6),
                                                            decoration: BoxDecoration(
                                                                color: Colors.white.withValues(alpha: 0.2),
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(Icons.close,
                                                                color: Colors.white, size: 16),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                            const SizedBox(height: 14),
                                            // Buyer name (prominent)
                                            Text(
                                                sale.buyerName,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.2,
                                                ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                                saleDate,
                                                style: const TextStyle(
                                                    color: Colors.white70, fontSize: 13),
                                            ),
                                            const SizedBox(height: 14),
                                            // Amount + payment status badges
                                            Row(children: [
                                                Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.22),
                                                        borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                        'R${sale.totalSaleAmount.toStringAsFixed(2)}',
                                                        style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 15,
                                                        ),
                                                    ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                        color: isPaid
                                                            ? Colors.white.withValues(alpha: 0.9)
                                                            : AppColors.warning.withValues(alpha: 0.85),
                                                        borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                            Icon(
                                                                isPaid
                                                                    ? Icons.check_circle_rounded
                                                                    : Icons.schedule_rounded,
                                                                size: 13,
                                                                color: isPaid
                                                                    ? AppColors.success
                                                                    : Colors.white,
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                                sale.paymentStatus,
                                                                style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: isPaid
                                                                        ? AppColors.success
                                                                        : Colors.white,
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ]),
                                        ],
                                    ),
                                ),

                                // ── Details body ──────────────────────────────
                                Container(
                                    color: AppColors.surface(context),
                                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                                    child: Column(
                                        children: [
                                            if (sale.numberOfChickensSold > 0)
                                                _buildSaleDetailRow(context,
                                                    Icons.set_meal_rounded,
                                                    'Chickens Sold',
                                                    '${sale.numberOfChickensSold}'),
                                            if (sale.numberOfDozensSold > 0)
                                                _buildSaleDetailRow(context,
                                                    Icons.egg_outlined,
                                                    'Dozens Sold',
                                                    '${sale.numberOfDozensSold}'),
                                            if (sale.salePricePerDozen > 0)
                                                _buildSaleDetailRow(context,
                                                    Icons.attach_money,
                                                    'Price per Dozen',
                                                    'R${sale.salePricePerDozen.toStringAsFixed(2)}'),
                                            if (sale.salePricePerChicken > 0)
                                                _buildSaleDetailRow(context,
                                                    Icons.attach_money,
                                                    'Price per Chicken',
                                                    'R${sale.salePricePerChicken.toStringAsFixed(2)}'),
                                            _buildSaleDetailRow(context,
                                                Icons.monetization_on_outlined,
                                                'Total Amount',
                                                'R${sale.totalSaleAmount.toStringAsFixed(2)}',
                                                valueColor: AppColors.success),
                                            _buildSaleDetailRow(context,
                                                isPaid
                                                    ? Icons.check_circle_rounded
                                                    : Icons.schedule_rounded,
                                                'Payment Status',
                                                sale.paymentStatus,
                                                valueColor: isPaid
                                                    ? AppColors.success
                                                    : AppColors.warning),
                                            _buildSaleDetailRow(context,
                                                Icons.calendar_today_outlined,
                                                'Sale Date',
                                                saleDate),
                                        ],
                                    ),
                                ),

                                // ── Close button ──────────────────────────────
                                Container(
                                    color: AppColors.surface(context),
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.adaptivePrimary(context),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12)),
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                            ),
                                            child: const Text(
                                                'Close',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                ),
                                            ),
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    ),
                );
            },
        );
    }

    Widget _buildSaleDetailRow(
        BuildContext context,
        IconData icon,
        String label,
        String value, {
        Color? valueColor,
    }) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
                children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: AppColors.surfaceVariant(context),
                            borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon,
                            size: 16, color: AppColors.adaptivePrimary(context)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                    label,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary(context),
                                    ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                    value,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: valueColor ??
                                            AppColors.textPrimary(context),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ],
            ),
        );
    }

    void _handleMenuSelection(
        String value, Coop coop, String farmId, VoidCallback onCoopUpdated) {
        switch (value) {
            case 'updateCoop':
                _showUpdateCoopBottomSheet(context, coop, farmId, onCoopUpdated);
                break;
            case 'recordMortality':
                _showRecordMortalityBottomSheet(coop, farmId, onCoopUpdated);
                break;
            case 'details':
                _showDialog(
                    'Coop Details', 'Here are the detailed statistics for this coop.');
                break;
            case 'deleteCoop':
                _deleteCoopDialog(coop, farmId, onCoopUpdated);
                break;
            case 'recordSale':
                if (coop.coopType == "BROILER") {
                    _showBroilerRecordSalesBottomSheet(coop, farmId, onCoopUpdated);
                } else {
                    _showLayersRecordSalesBottomSheet(coop, farmId, onCoopUpdated);
                }
                break;
            case 'recordExpense':
                _showRecordExpenseBottomSheet(coop, farmId, onCoopUpdated);
                break;
            case 'newBatch':
                _showAddBatchConfirmationBottomSheet(coop, farmId, onCoopUpdated);
                break;
        }
    }

    void _showAddBatchConfirmationBottomSheet(
        Coop coop, String farmId, VoidCallback onCoopUpdated) {
        final formKey = GlobalKey<FormState>();

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Confirm New Batch Addition',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                                const SizedBox(height: 24),
                                                                const Text(
                                                                    "Are you sure you want to add a new batch? "
                                                                    "All previous batch records will be archived and "
                                                                    "are accessible in your farm’s history for reporting purposes.",
                                                                    style: TextStyle(fontSize: 14),
                                                                ),
                                                                const SizedBox(height: 16),
                                                                const Text(
                                                                    "Once this new batch is added:",
                                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                                                ),
                                                                const SizedBox(height: 8),
                                                                const ListTile(
                                                                    leading: Icon(Icons.fiber_manual_record, size: 8),
                                                                    title: Text(
                                                                        "Clean Slate: All data tracking, "
                                                                        "such as sales and mortality, "
                                                                        "will start fresh for this batch.",
                                                                        style: TextStyle(fontSize: 14),
                                                                    ),
                                                                ),
                                                                const ListTile(
                                                                    leading: Icon(Icons.fiber_manual_record, size: 8),
                                                                    title: Text(
                                                                        "Coop Cleaning: The coop is marked as clean, "
                                                                        "ready to support the health of your new flock.",
                                                                        style: TextStyle(fontSize: 14),
                                                                    ),
                                                                ),
                                                                const ListTile(
                                                                    leading: Icon(Icons.fiber_manual_record, size: 8),
                                                                    title: Text(
                                                                        "Batch-Specific Tracking: "
                                                                        "You’ll have detailed "
                                                                        "tracking for this specific batch, "
                                                                        "helping you monitor its unique performance.",
                                                                        style: TextStyle(fontSize: 14),
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 16),
                                                                const Text(
                                                                    "If you’re ready to begin, "
                                                                    "please confirm. Otherwise, "
                                                                    "you may return to review current records.",
                                                                    style: TextStyle(fontSize: 14),
                                                                ),

                                                                const SizedBox(height: 36),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                onPressed: () async {
                                                                                    Navigator.of(context).pop();
                                                                                    _showAddNewBatchBottomSheet(coop, farmId, onCoopUpdated);
                                                                                },
                                                                                child:  Text(
                                                                                    'Confirm',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surface(context),
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    void _showAddNewBatchBottomSheet(
        Coop coop, String farmId, VoidCallback onCoopUpdated) {
        final formKey = GlobalKey<FormState>();
        String coopName = coop.coopName;
        String coopType = coop.coopType.toLowerCase().capitalize();
        GrowingPhase growthPhase = coop.growthPhase;
        int numberOfChickens = 0;
        DateTime? chickenArrivalDate;
        bool showGrowthPhaseError = false;
        bool showCoopTypeError = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Add New Chicken Batch',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                                const SizedBox(height: 24),

                                                                Common.buildTextField(
                                                                    label: 'Coop Name',
                                                                    icon: Icons.home_outlined,
                                                                    initialValue: coopName,
                                                                    onChanged: (value) => coopName = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter a coop name'
                                                                        : null,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Common.buildCoopTypeSegmentedControl(
                                                                    selectedCoopType: coopType,
                                                                    showError: showCoopTypeError,
                                                                    context: context,
                                                                    onChanged: (val) => setModalState(() {
                                                                            coopType = val;
                                                                            showCoopTypeError = false;
                                                                        }),
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Common.buildGrowthPhaseSegmentedControl(
                                                                    growthPhase: growthPhase,
                                                                    showError: showGrowthPhaseError,
                                                                    onChanged: (val) => setModalState(() {
                                                                            growthPhase = val;
                                                                            showGrowthPhaseError = false;
                                                                        }),
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                FormField<DateTime>(
                                                                    builder: (field) {
                                                                        return Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                                Common.buildDateField(
                                                                                    context: context,
                                                                                    label: 'Chicken Arrival Date (Optional)',
                                                                                    date: chickenArrivalDate,
                                                                                    onDateSelected: (date) {
                                                                                        setState(() {
                                                                                                chickenArrivalDate = date;
                                                                                                field.didChange(date);
                                                                                            });
                                                                                    },
                                                                                ),
                                                                            ],
                                                                        );
                                                                    },
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Number of Chickens (Optional)',
                                                                    icon: Icons.fact_check_outlined,
                                                                    initialValue: numberOfChickens.toString(),
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    numberOfChickens = int.tryParse(value) ?? 0,
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 36),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                onPressed: () async {
                                                                                    final isFormValid = formKey.currentState!.validate();
                                                                                    final isCoopTypeValid = coopType.trim().isNotEmpty;
                                                                                    final isGrowthPhaseValid = growthPhase.toString().trim().isNotEmpty;

                                                                                    setModalState(() {
                                                                                            showCoopTypeError = !isCoopTypeValid;
                                                                                            showGrowthPhaseError = !isGrowthPhaseValid;
                                                                                        });

                                                                                    if (!isFormValid || !isCoopTypeValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

                                                                                    final response = await service.addNewBatch(
                                                                                        farmId: farmId,
                                                                                        coopId: coop.id,
                                                                                        coopName: coopName,
                                                                                        coopType: coopType,
                                                                                        growthPhase: growthPhase,
                                                                                        numberOfChickens: numberOfChickens,
                                                                                        chickenArrivalDate:
                                                                                        chickenArrivalDate?.toIso8601String(),
                                                                                    );

                                                                                    if (context.mounted) {
                                                                                        Navigator.of(context, rootNavigator: true).pop();
                                                                                    }

                                                                                    if (response.success) {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/success_check.json',
                                                                                            autoCloseAfter: const Duration(seconds: 2),
                                                                                        );
                                                                                        if (context.mounted) Navigator.of(context).pop();
                                                                                        onCoopUpdated();
                                                                                    } else {
                                                                                        await Common.showLottieDialog(
                                                                                            context,
                                                                                            lottiePath: 'assets/lottie/error.json',
                                                                                            message: response.message,
                                                                                            autoCloseAfter:  Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child:  Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surface(context),
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    PopupMenuItem<String> _buildPopupMenuItem(
        String value, IconData icon, String text, Color color) {
        return PopupMenuItem<String>(
            value: value,
            child: Row(
                children: [
                    Icon(icon, color: color, size: 20),
                    const SizedBox(width: 10),
                    Text(
                        text,
                        style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w500,
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildInfoRow(IconData icon, String label, String value) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 2.0),
            child: Row(
                children: [
                    Icon(icon, size: 20, color: AppColors.adaptivePrimary(context)),
                    const SizedBox(width: 8),
                    Text(
                        '$label: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(value),
                ],
            ),
        );
    }

    void _deleteCoopDialog(Coop coop, String farmId, VoidCallback onCoopDeleted) {
        String title = 'Delete Coop';
        String content = 'Are you sure you want to delete this coop '
            '(${coop.coopName})? This action cannot be undone.';

        showDialog(
            context: context,
            builder: (BuildContext context) {
                return AlertDialog(
                    title: Text(
                        title,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.adaptivePrimary(context),
                        ),
                    ),
                    content: Text(content),
                    actions: <Widget>[
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.adaptivePrimary(context),
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                                Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                        ),
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: AppColors.warning,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                                final MessageResponse response =
                                    await service.deleteFarmCoop(farmId, coop.id);

                                if (response.success) {
                                    onCoopDeleted();
                                    Navigator.of(context).pop();
                                } else {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        Common.buildSnackBar(response.message, AppColors.error),
                                    );
                                }
                            },
                            child: const Text('Confirm'),
                        ),
                    ],
                );
            },
        );
    }

    void _showUpdateCoopBottomSheet(
        BuildContext context,
        Coop coop,
        String farmId,
        VoidCallback onCoopUpdated,
    ) {
        final formKey = GlobalKey<FormState>();
        String coopName = coop.coopName;
        String coopType = coop.coopType.toLowerCase().capitalize();
        GrowingPhase growthPhase = coop.growthPhase;
        int numberOfChickens = coop.numberOfChickens;
        DateTime? chickenArrivalDate = coop.chickenArrivalDate.isNotEmpty && coop.chickenArrivalDate != "Unknown"
            ? DateTime.parse(coop.chickenArrivalDate)
            : null;
        bool showCoopTypeError = false;
        bool showGrowthPhaseError = false;
        bool isLoading = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Update Coop',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,
                                                            children: [
                                                                const SizedBox(height: 24),

                                                                Common.buildTextField(
                                                                    label: 'Coop Name',
                                                                    icon: Icons.home_outlined,
                                                                    initialValue: coopName,
                                                                    onChanged: (value) => coopName = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter a coop name'
                                                                        : null,
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 10),

                                                                Common.buildCoopTypeSegmentedControl(
                                                                    selectedCoopType: coopType,
                                                                    showError: showCoopTypeError,
                                                                    context: context,
                                                                    onChanged: (val) => setModalState(() {
                                                                            coopType = val;
                                                                            showCoopTypeError = false;
                                                                        }),
                                                                ),

                                                                const SizedBox(height: 10),

                                                                Common.buildGrowthPhaseSegmentedControl(
                                                                    growthPhase: growthPhase,
                                                                    showError: showGrowthPhaseError,
                                                                    onChanged: (val) => setModalState(() {
                                                                            growthPhase = val;
                                                                            showGrowthPhaseError = false;
                                                                        }),
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 36),

                                                                Common.buildDateField(
                                                                    context: context,
                                                                    label: 'Chicken Arrival Date (Optional)',
                                                                    date: chickenArrivalDate,
                                                                    onDateSelected: (date) =>
                                                                    setModalState(() => chickenArrivalDate = date),
                                                                ),

                                                                const SizedBox(height: 36),

                                                                Common.buildTextField(
                                                                    label: 'Number of Chickens (Optional)',
                                                                    icon: Icons.fact_check_outlined,
                                                                    initialValue: numberOfChickens.toString(),
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) => numberOfChickens = int.tryParse(value) ?? 0,
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 36),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                 onPressed: isLoading ? null : () async {
                                                                                    final isFormValid = formKey.currentState!.validate();
                                                                                    final isCoopTypeValid = coopType.trim().isNotEmpty;
                                                                                    final isGrowthPhaseValid = growthPhase.toString().trim().isNotEmpty;

                                                                                    setModalState(() {
                                                                                            showCoopTypeError = !isCoopTypeValid;
                                                                                            showGrowthPhaseError = !isGrowthPhaseValid;
                                                                                        });

                                                                                    if (!isFormValid || !isCoopTypeValid) return;

                                                                                    setModalState(() => isLoading = true);

                                                                                    final response = await service.updateFarmCoop(
                                                                                        farmId: farmId,
                                                                                        coopId: coop.id,
                                                                                        coopName: coopName,
                                                                                        coopType: coopType,
                                                                                        growthPhase: growthPhase,
                                                                                        numberOfChickens: numberOfChickens,
                                                                                        chickenArrivalDate: chickenArrivalDate?.toIso8601String(),
                                                                                    );

                                                                                    if (!context.mounted) return;
                                                                                    setModalState(() => isLoading = false);

                                                                                    if (response.success) {
                                                                                        HapticFeedback.mediumImpact();
                                                                                        Navigator.of(context).pop();
                                                                                        onCoopUpdated();
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar('Coop updated successfully!', AppColors.success),
                                                                                        );
                                                                                    } else {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar(response.message, AppColors.error),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: isLoading
                                                                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                                                                    : Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surface(context),
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    Future<void> _showBroilerRecordSalesBottomSheet(
        Coop coop, String farmId, VoidCallback onCoopUpdated) async {
        final userData = await SessionManager().get("userData");
        User user = User.fromJson(userData as Map<String, dynamic>);

        final formKey = GlobalKey<FormState>();
        String buyerName = '';
        String? paymentStatus;
        int numberOfChickensSold = 0;
        double salePricePerChicken = 0;
        DateTime? saleDate;
        String recordedBy = user.id;
        bool isSaleDateError = false;
        bool showPaymentStatusError = false;
        bool isLoading = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Frosted glass header
                                        _buildFrostedSheetHeader('Record Sale'),
                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,

                                                            children: [
                                                                const SizedBox(height: 24),
                                                                Common.buildStepperField(
                                                                    label: 'Number Of Chickens Sold',
                                                                    value: numberOfChickensSold,
                                                                    onChanged: (val) => setModalState(() => numberOfChickensSold = val),
                                                                    min: 0,
                                                                    context: context,
                                                                    validator: (val) => val == null || val <= 0
                                                                        ? 'Please enter number of chickens sold'
                                                                        : null,
                                                                ),

                                                                const SizedBox(height: 22),

                                                                Common.buildCurrencyField(
                                                                    label: 'Sale Price Per Chicken',
                                                                    onChanged: (value) => salePricePerChicken = value,
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 22),

                                                                Common.buildTextField(
                                                                    label: 'Buyer Name',
                                                                    icon: Icons.account_circle_outlined,
                                                                    onChanged: (value) => buyerName = value,
                                                                    validator: (value) =>
                                                                    value == null || value.isEmpty ? 'Please enter buyer name' : null,
                                                                    context: context,
                                                                ),

                                                                                const SizedBox(height: 22),

                                                                                FormField<DateTime>(
                                                                                    validator: (value) {
                                                                                        if (saleDate == null) {
                                                                                            return 'Please select a sale date';
                                                                                        }
                                                                                        return null;
                                                                                    },
                                                                                    builder: (field) {
                                                                                        final hasError = field.hasError;
                                                                                        return Common.buildDateField(
                                                                                            context: context,
                                                                                            label: 'Sale Date',
                                                                                            date: saleDate,
                                                                                            hasError: hasError,
                                                                                            errorText: 'Please select a sale date',
                                                                                            onDateSelected: (date) {
                                                                                                setModalState(() {
                                                                                                        saleDate = date;
                                                                                                        field.didChange(date);
                                                                                                    });
                                                                                            },
                                                                                        );
                                                                                    },
                                                                                ),

                                                                                const SizedBox(height: 18),

                                                                Common.buildPaymentStatusSegmentedControl(
                                                                    value: paymentStatus,
                                                                    showError: showPaymentStatusError,
                                                                    context: context,
                                                                    onChanged: (val) {
                                                                        setModalState(() {
                                                                                paymentStatus = val;
                                                                                showPaymentStatusError = false;
                                                                            });
                                                                    },
                                                                ),

                                                                const SizedBox(height: 36),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                 onPressed: () async {

                                                                                    final isFormValid = formKey.currentState!.validate();
                                                                                    final isPaymentStatusValid = paymentStatus != null && paymentStatus!.trim().isNotEmpty;

                                                                                    setModalState(() {
                                                                                            showPaymentStatusError = !isPaymentStatusValid;
                                                                                            isSaleDateError = saleDate == null;
                                                                                        });

                                                                                    if (!isFormValid || !isPaymentStatusValid || numberOfChickensSold <= 0 || salePricePerChicken <= 0) return;

                                                                                    setModalState(() => isLoading = true);

                                                                                    final response = await service.updateSales(
                                                                                        id: null,
                                                                                        farmId: farmId,
                                                                                        coopId: coop.id,
                                                                                        numberOfDozensSold: null,
                                                                                        salePricePerDozen: null,
                                                                                        numberOfChickensSold: numberOfChickensSold,
                                                                                        salePricePerChicken: salePricePerChicken,
                                                                                        buyerName: buyerName,
                                                                                        recordedBy: recordedBy,
                                                                                        paymentStatus: paymentStatus ?? '',
                                                                                        saleDate: saleDate!.toIso8601String(),
                                                                                    );

                                                                                    if (!context.mounted) return;
                                                                                    setModalState(() => isLoading = false);

                                                                                    if (response.success) {
                                                                                        HapticFeedback.mediumImpact();
                                                                                        Navigator.of(context).pop();
                                                                                        onCoopUpdated();
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar('Sale recorded successfully!', AppColors.success),
                                                                                        );
                                                                                    } else {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar(response.message, AppColors.error),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: isLoading
                                                                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                                                                    : const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surfaceLight,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                             ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                                const SizedBox(height: 16),
                                                            ],

                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    Future<void> _showLayersRecordSalesBottomSheet(
        Coop coop, String farmId, VoidCallback onCoopUpdated) async {
        final userData = await SessionManager().get("userData");

        User user = User.fromJson(userData as Map<String, dynamic>);
        final formKey = GlobalKey<FormState>();
        String buyerName = '';
        String? paymentStatus;
        int numberOfDozensSold = 0;
        double salePricePerDozen = 0;
        DateTime? saleDate;
        String recordedBy = user.id;
        bool isSaleDateError = false;
        bool showPaymentStatusError = false;
        bool isLoading = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Record Sale',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,

                                                            children: [
                                                                const SizedBox(height: 24),
                                                                Common.buildStepperField(
                                                                    label: 'Number Of Dozens Sold',
                                                                    value: numberOfDozensSold,
                                                                    onChanged: (val) => setModalState(() => numberOfDozensSold = val),
                                                                    min: 0,
                                                                    context: context,
                                                                    validator: (val) => val == null || val <= 0
                                                                        ? 'Please enter number of dozens sold'
                                                                        : null,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildCurrencyField(
                                                                    label: 'Sale Price Per Dozen',
                                                                    onChanged: (value) => salePricePerDozen = value,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Buyer Name',
                                                                    icon: Icons.account_box_outlined,
                                                                    onChanged: (value) => buyerName = value,
                                                                    validator: (value) => value == null || value.isEmpty
                                                                        ? 'Please enter buyer name'
                                                                        : null,
                                                                    context: context,
                                                                ),

                                                                                const SizedBox(height: 22),
                                                                                FormField<DateTime>(
                                                                                    validator: (value) {
                                                                                        if (saleDate == null) {
                                                                                            return 'Please select a sale date';
                                                                                        }
                                                                                        return null;
                                                                                    },
                                                                                    builder: (field) {
                                                                                        final hasError = field.hasError;
                                                                                        return Common.buildDateField(
                                                                                            context: context,
                                                                                            label: 'Sale Date',
                                                                                            date: saleDate,
                                                                                            hasError: hasError,
                                                                                            errorText: 'Please select a sale date',
                                                                                            onDateSelected: (date) {
                                                                                                setModalState(() {
                                                                                                        saleDate = date;
                                                                                                        field.didChange(date);
                                                                                                    });
                                                                                            },
                                                                                        );
                                                                                    },
                                                                                ),
                                                                                const SizedBox(height: 18),

                                                                Common.buildPaymentStatusSegmentedControl(
                                                                    value: paymentStatus,
                                                                    showError: showPaymentStatusError,
                                                                    context: context,
                                                                    onChanged: (val) {
                                                                        setModalState(() {
                                                                                paymentStatus = val;
                                                                                showPaymentStatusError = false;
                                                                            });
                                                                    },
                                                                ),

                                                                const SizedBox(height: 24),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                 onPressed: isLoading ? null : () async {

                                                                                    final isFormValid = formKey.currentState!.validate();
                                                                                    final isPaymentStatusValid = paymentStatus != null && paymentStatus!.trim().isNotEmpty;

                                                                                    setModalState(() {
                                                                                            showPaymentStatusError = !isPaymentStatusValid;
                                                                                            isSaleDateError = saleDate == null;
                                                                                        });

                                                                                    if (!isFormValid || !isPaymentStatusValid) return;

                                                                                    setModalState(() => isLoading = true);

                                                                                     final response = await service.updateSales(
                                                                                        id: null,
                                                                                        farmId: farmId,
                                                                                        coopId: coop.id,
                                                                                        numberOfDozensSold: numberOfDozensSold,
                                                                                        salePricePerDozen: salePricePerDozen,
                                                                                        numberOfChickensSold: null,
                                                                                        salePricePerChicken: null,
                                                                                        buyerName: buyerName,
                                                                                        recordedBy: recordedBy,
                                                                                        paymentStatus: paymentStatus ?? '',
                                                                                        saleDate: saleDate!.toIso8601String(),
                                                                                    );

                                                                                    if (!context.mounted) return;
                                                                                    setModalState(() => isLoading = false);

                                                                                    if (response.success) {
                                                                                        HapticFeedback.mediumImpact();
                                                                                        Navigator.of(context).pop();
                                                                                        onCoopUpdated();
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar('Sale recorded successfully!', AppColors.success),
                                                                                        );
                                                                                    } else {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar(response.message, AppColors.error),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: isLoading
                                                                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                                                                    : const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surfaceLight,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],

                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    Future<void> _showRecordEggsBottomSheet(
        Coop coop, String farmId, VoidCallback onCoopUpdated) async {
        final userData = await SessionManager().get("userData");

        User user = User.fromJson(userData as Map<String, dynamic>);
        final formKey = GlobalKey<FormState>();
        int numberOfBoxes = 0;
        EggSize? eggSize = EggSize.LARGE;
        BoxSize? boxSize = BoxSize.THIRTY_EGGS_BOX;
        bool showEggSizeError = false;
        bool showBoxSizeError = false;
        String additionalInfo = '';
        DateTime? recordingDate = DateTime.now();
        bool isLoading = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Record Packaged Eggs',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,

                                                            children: [
                                                                const SizedBox(height: 24),
                                                                Common.buildStepperField(
                                                                    label: 'Number of Boxes',
                                                                    value: numberOfBoxes,
                                                                    onChanged: (val) => setModalState(() => numberOfBoxes = val),
                                                                    min: 0,
                                                                    context: context,
                                                                    validator: (val) => val == null || val <= 0
                                                                        ? 'Please enter number of boxes'
                                                                        : null,
                                                                ),

                                                                const SizedBox(height: 8),
                                                                Common.buildEggSizesRadioButtons(
                                                                    eggSize: eggSize,
                                                                    showError: showEggSizeError,
                                                                    onChanged: (val) => setModalState(() {
                                                                            eggSize = val;
                                                                            showEggSizeError = false;
                                                                        }),
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Common.buildBoxSizesWithScrollDots(
                                                                    boxSize: boxSize,
                                                                    showError: showBoxSizeError,
                                                                    onChanged: (val) => setModalState(() {
                                                                            boxSize = val;
                                                                            showBoxSizeError = false;
                                                                        }),
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 8),
                                                                FormField<DateTime>(
                                                                    builder: (field) {
                                                                        return Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                                Common.buildDateField(
                                                                                    context: context,
                                                                                    label: 'Recording Date',
                                                                                    date: recordingDate,
                                                                                    onDateSelected: (date) {
                                                                                        setModalState(() {
                                                                                                recordingDate = date;
                                                                                                field.didChange(date);
                                                                                            });
                                                                                    },
                                                                                ),
                                                                            ],
                                                                        );
                                                                    },
                                                                ),
                                                                const SizedBox(height: 8),
                                                                Common.buildTextField(
                                                                    label: 'Additional Info (Optional)',
                                                                    icon: Icons.account_box_outlined,
                                                                    onChanged: (value) => additionalInfo = value,
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 24),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                 onPressed: isLoading ? null : () async {

                                                                                    final isFormValid = formKey.currentState!.validate();

                                                                                    setModalState(() {
                                                                                            showEggSizeError = eggSize == null;
                                                                                            showBoxSizeError = boxSize == null;
                                                                                        });

                                                                                    if (!isFormValid || numberOfBoxes <= 0) return;

                                                                                    setModalState(() => isLoading = true);

                                                                                    final response = await service.recordPackaging(
                                                                                        userId: user.id,
                                                                                        farmId: farmId,
                                                                                        coopId: coop.id,
                                                                                        eggSize: eggSize!.value,
                                                                                        boxSize: boxSize!.value,
                                                                                        numberOfBoxes: numberOfBoxes,
                                                                                        additionalInfo: additionalInfo,
                                                                                        createdDate: recordingDate?.toIso8601String(),
                                                                                    );

                                                                                    if (!context.mounted) return;
                                                                                    setModalState(() => isLoading = false);

                                                                                    if (response.success) {
                                                                                        HapticFeedback.mediumImpact();
                                                                                        Navigator.of(context).pop();
                                                                                        onCoopUpdated();
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar('Eggs recorded successfully!', AppColors.success),
                                                                                        );
                                                                                    } else {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar(response.message, AppColors.error),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: isLoading
                                                                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                                                                    : const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surfaceLight,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],

                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    Future<void> _showRecordMortalityBottomSheet(
        Coop coop, String farmId, VoidCallback onCoopUpdated) async {
        final userData = await SessionManager().get("userData");

        User user = User.fromJson(userData as Map<String, dynamic>);
        final formKey = GlobalKey<FormState>();
        String reason = 'Select mortality reason';
        int numberOfDeaths = 0;
        DateTime? dateOccurred;
        String recordedBy = user.id;
        bool isSaleDateError = false;
        bool hasSubmitted = false;
        bool isLoading = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Record Mortality',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,

                                                            children: [
                                                                const SizedBox(height: 24),
                                                                Common.buildStepperField(
                                                                    label: 'Number Of Deaths',
                                                                    value: numberOfDeaths,
                                                                    onChanged: (val) => setModalState(() => numberOfDeaths = val),
                                                                    min: 0,
                                                                    context: context,
                                                                    validator: (val) => val == null || val <= 0
                                                                        ? 'Please enter number of deaths'
                                                                        : null,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                                FormField<DateTime>(
                                                                                    validator: (value) {
                                                                                        if (dateOccurred == null) {
                                                                                            return 'Please select date';
                                                                                        }
                                                                                        return null;
                                                                                    },
                                                                                    builder: (field) {
                                                                                        return Common.buildDateField(
                                                                                            context: context,
                                                                                            label: 'When did this occurred?',
                                                                                            date: dateOccurred,
                                                                                            hasError: field.hasError,
                                                                                            errorText: 'Please select a date',
                                                                                            onDateSelected: (date) {
                                                                                                setModalState(() {
                                                                                                        dateOccurred = date;
                                                                                                        field.didChange(date);
                                                                                                    });
                                                                                            },
                                                                                        );
                                                                                    },
                                                                                ),
                                                                const SizedBox(height: 22),
                                                                MortalityDropdown(
                                                                    value: reason,
                                                                    onChanged: (val) {
                                                                        setState(() {
                                                                                reason = val ?? 'Select mortality reason';
                                                                            });
                                                                    },
                                                                    hasSubmitted: hasSubmitted,
                                                                    validator: (val) {
                                                                        if (hasSubmitted && (val == null || val == 'Select mortality reason')) {
                                                                            return 'Please select a valid reason';
                                                                        }
                                                                        return null;
                                                                    },
                                                                ),

                                                                const SizedBox(height: 24),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                 onPressed: isLoading ? null : () async {

                                                                                    hasSubmitted = true;
                                                                                    final isFormValid = formKey.currentState!.validate();

                                                                                    setModalState(() {
                                                                                            isSaleDateError = dateOccurred == null;
                                                                                        });

                                                                                    if (!isFormValid || numberOfDeaths <= 0) return;

                                                                                    setModalState(() => isLoading = true);

                                                                                    final response = await service.updateMortality(
                                                                                        id: null,
                                                                                        farmId: farmId,
                                                                                        coopId: coop.id,
                                                                                        dateOccurred:
                                                                                        dateOccurred!.toIso8601String(),
                                                                                        numberOfDeaths: numberOfDeaths,
                                                                                        reason: reason,
                                                                                        recordedBy: recordedBy,
                                                                                    );

                                                                                    if (!context.mounted) return;
                                                                                    setModalState(() => isLoading = false);

                                                                                    if (response.success) {
                                                                                        HapticFeedback.mediumImpact();
                                                                                        Navigator.of(context).pop();
                                                                                        onCoopUpdated();
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar('Mortality recorded successfully!', AppColors.success),
                                                                                        );
                                                                                    } else {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar(response.message, AppColors.error),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: isLoading
                                                                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                                                                    : const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surfaceLight,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],

                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    Future<void> _showRecordExpenseBottomSheet(
        Coop coop, String farmId, VoidCallback onCoopUpdated) async {
        final userData = await SessionManager().get("userData");

        User user = User.fromJson(userData as Map<String, dynamic>);
        final formKey = GlobalKey<FormState>();
        String additionalInfo = '';
        String expenseType = 'Select expense type';
        double amount = 0;
        DateTime? expenseDate;
        String recordedBy = user.id;
        bool isSaleDateError = false;
        bool hasSubmitted = false;
        bool isLoading = false;

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
                return DraggableScrollableSheet(
                    expand: false,
                    initialChildSize: 0.85,
                    minChildSize: 0.4,
                    maxChildSize: 0.95,
                    builder: (context, scrollController) {

                        return StatefulBuilder(
                            builder: (BuildContext context, StateSetter setModalState) {
                                return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Fixed header
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                            decoration: BoxDecoration(
                                                color: Theme.of(context).scaffoldBackgroundColor,
                                                borderRadius:
                                                const BorderRadius.vertical(top: Radius.circular(20)),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: AppColors.adaptivePrimary(context).withOpacity(0.2),
                                                        blurRadius: 10,
                                                        offset: const Offset(0, 2),
                                                    ),
                                                ],
                                            ),
                                            child: Center(
                                                child: Text(
                                                    'Record Expense',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.adaptivePrimary(context),
                                                        letterSpacing: 0.5,
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const Divider(height: 1),

                                        // Scrollable form
                                        Expanded(
                                            child: SingleChildScrollView(
                                                controller: scrollController,
                                                child: Padding(
                                                    padding: EdgeInsets.only(
                                                        left: 18,
                                                        right: 18,
                                                        top: 18,
                                                        bottom:
                                                        MediaQuery.of(context).viewInsets.bottom + 18,
                                                    ),
                                                    child: Form(
                                                        key: formKey,
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.stretch,

                                                            children: [
                                                                const SizedBox(height: 24),
                                                                ExpenseTypeDropdown(
                                                                    value: expenseType,
                                                                    onChanged: (val) => setState(() => expenseType = val ?? 'Select expense type'),
                                                                    showErrorOnlyAfterSubmit: hasSubmitted,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildCurrencyField(
                                                                    label: 'Amount',
                                                                    onChanged: (value) => amount = value,
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 22),
                                                                                FormField<DateTime>(
                                                                                    validator: (value) {
                                                                                        if (expenseDate == null) {
                                                                                            return 'Please select date';
                                                                                        }
                                                                                        return null;
                                                                                    },
                                                                                    builder: (field) {
                                                                                        return Common.buildDateField(
                                                                                            context: context,
                                                                                            label: 'Date of Expense',
                                                                                            date: expenseDate,
                                                                                            hasError: field.hasError,
                                                                                            errorText: 'Please select a date of expense',
                                                                                            onDateSelected: (date) {
                                                                                                setState(() {
                                                                                                        expenseDate = date;
                                                                                                        field.didChange(date);
                                                                                                    });
                                                                                            },
                                                                                        );
                                                                                    },
                                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Additional Info (Optional)',
                                                                    icon: Icons.account_box_outlined,
                                                                    onChanged: (value) => additionalInfo = value,
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 24),

                                                                Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                        Expanded(
                                                                            child: ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                    backgroundColor: AppColors.adaptivePrimary(context),
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                 onPressed: isLoading ? null : () async {

                                                                                    hasSubmitted = true;
                                                                                    final isFormValid = formKey.currentState!.validate();

                                                                                    setModalState(() {
                                                                                            isSaleDateError = expenseDate == null;
                                                                                        });

                                                                                    if (!isFormValid || amount <= 0) return;

                                                                                    setModalState(() => isLoading = true);

                                                                                    final response =
                                                                                        await service.updateExpenses(
                                                                                            id: null,
                                                                                            farmId: farmId,
                                                                                            coopId: coop.id,
                                                                                            expenseDate:
                                                                                            expenseDate!.toIso8601String(),
                                                                                            expenseType: expenseType,
                                                                                            amount: amount,
                                                                                            additionalInfo: additionalInfo,
                                                                                            recordedBy: recordedBy,
                                                                                        );

                                                                                    if (!context.mounted) return;
                                                                                    setModalState(() => isLoading = false);

                                                                                    if (response.success) {
                                                                                        HapticFeedback.mediumImpact();
                                                                                        Navigator.of(context).pop();
                                                                                        onCoopUpdated();
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar('Expense recorded successfully!', AppColors.success),
                                                                                        );
                                                                                    } else {
                                                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                                                            Common.buildSnackBar(response.message, AppColors.error),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: isLoading
                                                                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                                                                    : const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: AppColors.surfaceLight,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: AppColors.error,
                                                                                side: const BorderSide(color: AppColors.error),
                                                                                shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(12),
                                                                                ),
                                                                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                                            ),
                                                                            onPressed: () => Navigator.of(context).pop(),
                                                                            child: const Text(
                                                                                'Cancel',
                                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ],

                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                );
                            },
                        );
                    },
                );
            },
        );

    }

    // ── Frosted glass bottom sheet header ─────────────────────────────────
    Widget _buildFrostedSheetHeader(String title) {
        return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 8, 16),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.92),
                        border: Border(
                            bottom: BorderSide(
                                color: AppColors.border(context),
                                width: 0.5,
                            ),
                        ),
                    ),
                    child: Column(
                        children: [
                            // Drag handle
                            Center(
                                child: Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: AppColors.textTertiary(context)
                                            .withOpacity(0.4),
                                        borderRadius: BorderRadius.circular(2),
                                    ),
                                ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                                child: Text(
                                    title,
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.adaptivePrimary(context),
                                        letterSpacing: 0.3,
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    void _showErrorSnackBar(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.error),
        );
    }

    void _showSuccessSnackBar(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, AppColors.success),
        );
    }

    void _showDialog(String title, String content) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
                return AlertDialog(
                    title: Text(title),
                    content: Text(content),
                    actions: <Widget>[
                        TextButton(
                            child: const Text('Close'),
                            onPressed: () {
                                Navigator.of(context).pop();
                            },
                        ),
                        TextButton(
                            child: const Text('Confirm'),
                            onPressed: () {
                                // Implement the action for each option
                                Navigator.of(context).pop();
                            },
                        ),
                    ],
                );
            },
        );
    }
}

extension StringExtension on String {
    String capitalize() {
        return "${this[0].toUpperCase()}${substring(1)}";
    }
}
