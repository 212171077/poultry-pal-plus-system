import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../models/coop_report.dart';
import '../models/farm.dart';
import '../models/farm_report.dart';
import '../models/user.dart';

class FarmDashboard extends StatefulWidget {
    final Farm farm;
    final User user;
    final void Function(int tabIndex)? onNavigateToTab;
    final Future<void> Function()? onRefresh;

    const FarmDashboard({
        super.key,
        required this.farm,
        required this.user,
        this.onNavigateToTab,
        this.onRefresh,
    });

    @override
    State<FarmDashboard> createState() => _FarmDashboardState();
}

class _FarmDashboardState extends State<FarmDashboard> {
    bool _initialLoad = true;

    @override
    void initState() {
        super.initState();
        Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) setState(() => _initialLoad = false);
        });
    }

    Future<void> _handleRefresh() async {
        if (widget.onRefresh != null) await widget.onRefresh!();
    }

    bool _isDark(BuildContext context) =>
        Theme.of(context).brightness == Brightness.dark;

    String _formatMoney(double value) {
        final abs = value.abs();
        final sign = value < 0 ? '-' : '';
        if (abs >= 1000000) return '$sign${(abs / 1000000).toStringAsFixed(1)}M';
        if (abs >= 1000) return '$sign${(abs / 1000).toStringAsFixed(1)}k';
        return '$sign${abs.toStringAsFixed(0)}';
    }

    // ── BUILD ─────────────────────────────────────────────────────────────────

    @override
    Widget build(BuildContext context) {
        return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppColors.adaptivePrimary(context),
            child: _initialLoad
                ? _buildShimmer(context)
                : _buildContent(context, widget.farm.farmReport),
        );
    }

    Widget _buildContent(BuildContext context, FarmReport report) {
        final double profit = report.totalSales - report.totalExpenses;
        final double mortalityRate = report.totalChickens > 0
            ? (report.totalMortalities / report.totalChickens * 100)
            : 0.0;

        return ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
            children: [
                _sectionHeader(context, 'Farm Summary'),
                const SizedBox(height: 12),
                _buildKpiGrid(context, report, profit, mortalityRate),
                const SizedBox(height: 24),

                _sectionHeader(context, 'Quick Actions'),
                const SizedBox(height: 12),
                _buildQuickActions(context),
                const SizedBox(height: 24),

                _sectionHeader(context, 'Coops Overview'),
                const SizedBox(height: 12),
                _buildCoopsSection(context, report),
            ],
        );
    }

    Widget _sectionHeader(BuildContext context, String title) {
        return Text(
            title,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.adaptivePrimary(context),
            ),
        );
    }

    // ── KPI GRID ──────────────────────────────────────────────────────────────

    Widget _buildKpiGrid(BuildContext context, FarmReport report,
        double profit, double mortalityRate) {
        final double total = report.totalSales + report.totalExpenses;
        final double revenueShare = total > 0 ? (report.totalSales / total * 100) : 0;
        final double expenseRatio = report.totalSales > 0
            ? (report.totalExpenses / report.totalSales * 100) : 0;
        final double profitMargin = report.totalSales > 0
            ? (profit / report.totalSales * 100) : 0;

        return Column(
            children: [
                Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Expanded(child: _kpiCard(context,
                            icon: Icons.trending_up_rounded,
                            title: 'Total Revenue',
                            value: 'R${_formatMoney(report.totalSales)}',
                            badge: '${revenueShare.toStringAsFixed(0)}% cashflow',
                            color: AppColors.success,
                            positive: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _kpiCard(context,
                            icon: Icons.trending_down_rounded,
                            title: 'Total Expenses',
                            value: 'R${_formatMoney(report.totalExpenses)}',
                            badge: '${expenseRatio.toStringAsFixed(0)}% of rev',
                            color: AppColors.error,
                            positive: false)),
                    ],
                ),
                const SizedBox(height: 12),
                Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Expanded(child: _kpiCard(context,
                            icon: Icons.account_balance_wallet_rounded,
                            title: 'Net Profit',
                            value: 'R${_formatMoney(profit)}',
                            badge: '${profitMargin.toStringAsFixed(0)}% margin',
                            color: profit >= 0 ? AppColors.info : AppColors.error,
                            positive: profit >= 0)),
                        const SizedBox(width: 12),
                        Expanded(child: _kpiCard(context,
                            icon: Icons.monitor_heart_rounded,
                            title: 'Mortality Rate',
                            value: '${mortalityRate.toStringAsFixed(1)}%',
                            badge: '${report.totalMortalities} of ${report.totalChickens}',
                            color: AppColors.warning,
                            positive: mortalityRate < 5.0)),
                    ],
                ),
            ],
        );
    }

    Widget _kpiCard(BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        required String badge,
        required Color color,
        required bool positive,
    }) {
        final ind = positive ? AppColors.success : AppColors.error;
        return Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            shadowColor: color.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.surface(context),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(icon, color: color, size: 17),
                                ),
                                const Spacer(),
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: ind.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            Icon(
                                                positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                                                size: 9, color: ind),
                                            const SizedBox(width: 1),
                                            Text(positive ? 'Good' : 'High',
                                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ind)),
                                        ],
                                    ),
                                ),
                            ],
                        ),
                        const SizedBox(height: 10),
                        Text(value,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary(context))),
                        const SizedBox(height: 2),
                        Text(title,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
                        Text(badge,
                            style: TextStyle(fontSize: 10, color: AppColors.textTertiary(context))),                    ],
                ),
            ),
        );
    }

    // ── QUICK ACTIONS ─────────────────────────────────────────────────────────

    Widget _buildQuickActions(BuildContext context) {
        final List<Map<String, dynamic>> actions = [
            {'icon': Icons.point_of_sale_rounded, 'label': 'Record\nSale', 'color': AppColors.success, 'tab': 2},
            {'icon': Icons.sick_rounded, 'label': 'Log\nMortality', 'color': AppColors.error, 'tab': 2},
            {'icon': Icons.receipt_long_rounded, 'label': 'Add\nExpense', 'color': AppColors.warning, 'tab': 2},
            {'icon': Icons.notifications_active_rounded, 'label': 'Check\nReminders', 'color': AppColors.info, 'tab': 0},
        ];

        return SizedBox(
            height: 86,
            child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: actions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                    final color = actions[i]['color'] as Color;
                    final tabIndex = actions[i]['tab'] as int;
                    return InkWell(
                        onTap: () => widget.onNavigateToTab?.call(tabIndex),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                            width: 95,
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                    Icon(actions[i]['icon'] as IconData, color: color, size: 24),
                                    const SizedBox(height: 6),
                                    Text(
                                        actions[i]['label'] as String,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: color,
                                            height: 1.2),
                                    ),
                                ],
                            ),
                        ),
                    );
                },
            ),
        );
    }

    // ── COOPS SECTION ─────────────────────────────────────────────────────────

    Widget _buildCoopsSection(BuildContext context, FarmReport report) {
        final active = report.coopReports.where((c) => c.totalChickens > 0).toList();
        if (active.isEmpty) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
                    child: Text(
                        'Your coops overview will appear here once you add chickens to a coop.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textTertiary(context),
                            fontWeight: FontWeight.w500),
                    ),
                ),
            );
        }
        return Column(children: active.map((c) => _buildCoopCard(context, c)).toList());
    }

    Widget _buildCoopCard(BuildContext context, CoopReport c) {
        final isBroiler = c.coopType.toUpperCase() == 'BROILER';
        final chipColor = isBroiler ? AppColors.warning : const Color(0xFF14B8A6);

        final healthScore = c.totalChickens > 0
            ? ((c.availableChickens / c.totalChickens) * 100).clamp(0.0, 100.0)
            : 0.0;
        final healthColor = healthScore >= 80
            ? AppColors.success
            : healthScore >= 60 ? AppColors.warning : AppColors.error;

        return Card(
            elevation: 3,
            shadowColor: AppColors.adaptivePrimary(context).withValues(alpha: 0.15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.surface(context),
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Header
                        Row(
                            children: [
                                Expanded(
                                    child: Text(
                                        c.coopName,
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.adaptivePrimary(context)),
                                    ),
                                ),
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: chipColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: chipColor.withValues(alpha: 0.5)),
                                    ),
                                    child: Text(c.coopType,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: chipColor)),
                                ),
                            ],
                        ),
                        const SizedBox(height: 14),

                        // Health circle + stats
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                                SizedBox(
                                    width: 80, height: 80,
                                    child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                            SizedBox(
                                                width: 80, height: 80,
                                                child: CircularProgressIndicator(
                                                    value: healthScore / 100,
                                                    strokeWidth: 7,
                                                    backgroundColor: AppColors.border(context),
                                                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                                                    strokeCap: StrokeCap.round,
                                                ),
                                            ),
                                            Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                    Text('${healthScore.toInt()}%',
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w700,
                                                            color: healthColor)),
                                                    Text('Health',
                                                        style: TextStyle(
                                                            fontSize: 9,
                                                            color: AppColors.textTertiary(context))),
                                                ],
                                            ),
                                        ],
                                    ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Column(
                                        children: [
                                            _metricRow(context, Icons.egg_rounded, 'Total', c.totalChickens.toString(), AppColors.warning),
                                            _metricRow(context, Icons.check_circle_outline_rounded, 'Available', c.availableChickens.toString(), AppColors.success),
                                            _metricRow(context, Icons.warning_amber_rounded, 'Mortality', c.totalMortality.toString(), AppColors.error),
                                            _metricRow(context, Icons.timer_outlined, 'Age', c.chickenAge, AppColors.info),
                                        ],
                                    ),
                                ),
                            ],
                        ),

                        const SizedBox(height: 14),
                        Divider(height: 1, color: AppColors.border(context)),
                        const SizedBox(height: 12),

                        _buildFinancialBars(context, c),
                    ],
                ),
            ),
        );
    }

    Widget _metricRow(BuildContext context, IconData icon, String label,
        String value, Color color) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
                children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 5),
                    Text('$label: ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                    Flexible(
                        child: Text(value,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary(context)),
                            overflow: TextOverflow.ellipsis),
                    ),
                ],
            ),
        );
    }

    Widget _buildFinancialBars(BuildContext context, CoopReport c) {
        final maxVal = [c.sales.abs(), c.expenses.abs(), c.profit.abs()]
            .reduce((a, b) => a > b ? a : b);

        if (maxVal < 1) {
            return Center(
                child: Text('No financial data yet',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary(context))));
        }

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                    children: [
                        Icon(Icons.bar_chart_rounded, size: 14, color: AppColors.adaptivePrimary(context)),
                        const SizedBox(width: 5),
                        Text('Financial Summary',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.adaptivePrimary(context))),
                    ],
                ),
                const SizedBox(height: 8),
                _barRow(context, 'Sales', c.sales, maxVal, AppColors.success),
                const SizedBox(height: 5),
                _barRow(context, 'Expenses', c.expenses, maxVal, AppColors.error),
                const SizedBox(height: 5),
                _barRow(context, 'Profit', c.profit, maxVal,
                    c.profit >= 0 ? AppColors.info : AppColors.error),
            ],
        );
    }

    Widget _barRow(BuildContext context, String label, double value,
        double maxVal, Color color) {
        final ratio = maxVal > 0 ? (value.abs() / maxVal).clamp(0.0, 1.0) : 0.0;
        return Row(
            children: [
                SizedBox(
                    width: 56,
                    child: Text(label,
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)))),
                Expanded(
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: color.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                        ),
                    ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                    width: 68,
                    child: Text('R${_formatMoney(value)}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis)),
            ],
        );
    }

    // ── SHIMMER SKELETON ──────────────────────────────────────────────────────

    Widget _buildShimmer(BuildContext context) {
        final dark = _isDark(context);
        return Shimmer.fromColors(
            baseColor: dark ? const Color(0xFF243224) : const Color(0xFFE8DDD5),
            highlightColor: dark ? const Color(0xFF3A5230) : const Color(0xFFF5EDE5),
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 96),
                children: [
                    _sBox(w: 130, h: 18),
                    const SizedBox(height: 12),
                    Row(children: [
                        Expanded(child: _sCard(h: 108)),
                        const SizedBox(width: 12),
                        Expanded(child: _sCard(h: 108)),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                        Expanded(child: _sCard(h: 108)),
                        const SizedBox(width: 12),
                        Expanded(child: _sCard(h: 108)),
                    ]),
                    const SizedBox(height: 24),
                    _sBox(w: 130, h: 18),
                    const SizedBox(height: 12),
                    SizedBox(
                        height: 86,
                        child: Row(
                            children: List.generate(4, (i) => Padding(
                                padding: EdgeInsets.only(right: i < 3 ? 12 : 0),
                                child: _sBox(w: 95, h: 86, r: 16),
                            )),
                        ),
                    ),
                    const SizedBox(height: 24),
                    _sBox(w: 130, h: 18),
                    const SizedBox(height: 12),
                    _sCard(h: 235),
                    const SizedBox(height: 14),
                    _sCard(h: 235),
                ],
            ),
        );
    }

    Widget _sBox({required double w, required double h, double r = 8}) {
        return Container(
            width: w, height: h,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(r)));
    }

    Widget _sCard({double h = 100}) {
        return Container(
            height: h,
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16)));
    }
}
