import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../models/farm.dart';
import '../models/farm_report.dart';
import '../models/user.dart';
import '../service/poultry_pal_service.dart';
import 'common.dart';

class FarmDashboard extends StatefulWidget {
    final Farm farm;
    final User user;

    const FarmDashboard({super.key, required this.farm, required this.user});

    @override
    State<FarmDashboard> createState() => _FarmDashboardState();
}

class _FarmDashboardState extends State<FarmDashboard> {
    @override
    Widget build(BuildContext context) {
        PoultryPalService service = PoultryPalService();
        return Scaffold(
            backgroundColor: AppColors.surfaceLight,
            body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Text(
                                'Farm Summary',
                                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 18, // Consistent font size
                                ),
                            ),

                            const SizedBox(height: 16),
                            _buildFarmSummary(widget.farm.farmReport),
                            const SizedBox(height: 20),

                            // Coop Overview Section
                            Text(
                                'Coops Overview',
                                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 18, // Consistent font size
                                ),
                            ),

                            widget.farm.farmReport.coopReports.isEmpty ?
                                const Center(
                                    child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                            'Your coops overview will appear here, '
                                            'providing a detailed summary of each coop\'s progress, '
                                            'including information on mortalities, expenses, profits, and sales.',
                                            textAlign: TextAlign.start,
                                            style: TextStyle(
                                                fontSize: 18,
                                                color: AppColors.textTertiaryLight,
                                                fontWeight: FontWeight.w500,
                                            ),
                                        ),
                                    ),
                                )
                                : Column(
                                    children: [
                                        const SizedBox(height: 10),
                                        ...widget.farm.farmReport.coopReports
                                            .where((coopReport) => coopReport.totalChickens > 0) // Only active coops
                                            .map((coopReport) {
                                                    return _buildCoopCard(
                                                        coopReport.coopName,
                                                        coopReport.coopType,
                                                        coopReport.totalChickens,
                                                        coopReport.chickenAge,
                                                        coopReport.totalMortality,
                                                        coopReport.sales,
                                                        coopReport.expenses,
                                                        coopReport.imageUrl,
                                                        context,
                                                    );
                                                }),
                                        const SizedBox(height: 20),
                                        const SingleChildScrollView(
                                            child: Column(
                                                children: [
                                                    SizedBox(height: 100), // Space at the bottom
                                                ],
                                            ),
                                        )
                                    ],

                                )
                        ],
                    ),
                ),
            ),
        );
    }

    Widget _buildFarmSummary(FarmReport report) {
        return Column(
            children: [
                // IconData icon, String title, String value, Color color
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                        _buildMetricCard(
                            Icons.fact_check_outlined,
                            'Total Chickens',
                            report.totalChickens.toStringAsFixed(0),
                            AppColors.warning,

                        ),
                        _buildMetricCard(
                            Icons.warning,
                            'Total Mortalities',
                            '${report.totalMortalities} Losses',
                            AppColors.textTertiaryLight,
                        ),
                    ],
                ),
                const SizedBox(height: 12),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                        _buildMetricCard(
                            Icons.attach_money,
                            'Total Sales',
                            'R${report.totalSales.toStringAsFixed(2)}',
                            AppColors.success,
                        ),
                        _buildMetricCard(
                            Icons.money_off,
                            'Total Expenses',
                            'R${report.totalExpenses.toStringAsFixed(2)}',
                            AppColors.error,
                        ),
                    ],
                ),
            ],
        );
    }

    Widget _buildMetricCard(
        IconData icon, String title, String value, Color color) {
        return Expanded(
            child: Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                color: AppColors.surfaceLight,
                shadowColor: color.withOpacity(0.5),
                elevation: 4,
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                        children: [
                            Icon(icon, size: 32, color: color),
                            const SizedBox(height: 6),
                            Text(
                                title,
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold, color: color),
                                textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                                value,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimaryLight),
                                textAlign: TextAlign.center,
                            ),
                        ],
                    ),
                ),
            ),
        );
    }

    Widget _buildCoopCard(
        String coopName,
        String coopType,
        int chickens,
        String age,
        int mortality,
        double totalSales,
        double totalExpenses,
        String imageUrl,
        BuildContext context) {
        int availableChickens = chickens - mortality;
        double profit = totalSales - totalExpenses;

        return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            color: AppColors.surfaceLight,
            // Adjusted card color for better contrast
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Column 1: Coop Details
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        coopName,
                                        style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).primaryColor),
                                    ),
                                    const SizedBox(height: 8),

                                    coopDetailDesign('Type', coopType, AppColors.primary, null, imageUrl),

                                    coopDetailDesign(
                                        'Total Chickens', chickens.toString(), AppColors.warning, Icons.fact_check, null),
                                    coopDetailDesign('Age', age, AppColors.info, Icons.timer, null),
                                    coopDetailDesign(
                                        'Mortality', mortality.toString(), AppColors.error, Icons.warning, null),
                                    coopDetailDesign('Available Chickens',
                                        availableChickens.toString(), AppColors.success, Icons.check_box, null),
                                ],
                            ),
                        ),

                        // Column 2: Enhanced Pie Chart
                        Expanded(
                            child: Column(
                                children: [
                                    SizedBox(
                                        height: 160,
                                        child: PieChart(
                                            PieChartData(
                                                sectionsSpace: 3,
                                                centerSpaceRadius: 35,
                                                startDegreeOffset: -90,
                                                sections: [
                                                    PieChartSectionData(
                                                        value: totalSales.toDouble() < 1 ? 0 : totalSales.toDouble(),
                                                        color: AppColors.infoLight,
                                                        title: 'Sales\nR$totalSales',
                                                        titleStyle: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.textSecondaryLight),
                                                        radius: 55,
                                                    ),
                                                    PieChartSectionData(
                                                        value: totalExpenses.toDouble() < 1 ? 0 : totalExpenses.toDouble(),
                                                        color: AppColors.errorLight,
                                                        title: 'Expenses\nR$totalExpenses',
                                                        titleStyle: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.textSecondaryLight),
                                                        radius: 45,
                                                    ),
                                                    PieChartSectionData(
                                                        value: profit.toDouble() < 1 ? 0 : profit.toDouble(),
                                                        color: AppColors.successLight,
                                                        title: 'Profit\nR$profit',
                                                        titleStyle: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.textSecondaryLight),
                                                        radius: 50,
                                                    ),
                                                ],
                                                borderData: FlBorderData(show: false),
                                                centerSpaceColor: Colors.white,
                                            ),
                                        ),
                                    ),
                                    const SizedBox(height: 6),
                                    if(totalSales.toDouble() > 0 || totalExpenses.toDouble() > 0 || profit.toDouble() > 0)
                                    Text(
                                        'Financial Overview',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(context).primaryColor),
                                    ),
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    Widget coopDetailDesign(String label, String value, Color color, IconData? icon,
        String? imagePath,) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
                children: [
                    if (icon != null) ...[
                        Icon(icon, size: 12, color: color),
                        const SizedBox(width: 6),
                    ],
                    if (imagePath != null) ...[
                        Image.asset(
                            imagePath,
                            width: 18,
                            height: 18,
                        ),
                        const SizedBox(width: 1),
                    ],
                    Text(
                        '$label: ',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 4),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: const BoxConstraints(maxWidth: 110), // optional max width
                        child: Text(
                            value,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, ),
                          textAlign: TextAlign.center,
                            softWrap: true,             // allows wrapping
                            overflow: TextOverflow.visible,
                        ),
                    ),

                ],
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
}
