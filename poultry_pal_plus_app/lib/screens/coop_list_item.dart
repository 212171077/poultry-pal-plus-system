import 'package:flutter/material.dart';
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

class _CoopListItemState extends State<CoopListItem> {
    bool _isExpanded = false;
    PoultryPalService service = PoultryPalService();
    bool isSalesExpanded = false;
    bool isMortalityExpanded = false;
    bool isExpensesExpanded = false;

    @override
    Widget build(BuildContext context) {
        return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.black12, width: 0.3),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _isExpanded
                        ? [Colors.brown[50]!, Colors.brown[300]!]
                        : [Colors.white, Colors.white],
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
                            child: widget.coop.active
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    duration: const Duration(seconds: 2),
                                    curve: Curves.easeInOut,
                                    builder: (context, value, child) {
                                        return Container(
                                            padding: const EdgeInsets.all(3), // Space for glow
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.green.withValues(
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
                                        // Restart the animation for continuous pulse
                                        if (mounted) setState(() {});
                                    },
                                    child: CircleAvatar(
                                        radius: 30,
                                        backgroundImage: AssetImage(widget.coop.imageUrl),
                                    ),
                                )
                                : Container(
                                    padding: const EdgeInsets.all(3), // Space for gray border
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
                        ),
                        title: Text(
                            widget.coop.coopName,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).primaryColor,
                            ),
                        ),
                        subtitle: Text(
                            "${widget.coop.coopType.toLowerCase().capitalize()} (${widget.coop.growthPhase.value})",
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).primaryColorDark,
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
                                    color: Colors.green,
                                ),
                            ),
                            onPressed: () {
                                setState(() {
                                        _isExpanded = !_isExpanded;
                                    });
                            },
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
                                        color: Colors.green,
                                        onTap: () => _showLayersRecordSalesBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                  ] else ...[
                                    _buildCompactButton(
                                        icon: Icons.monetization_on_outlined,
                                        label: 'Add Sales',
                                        color: Colors.green,
                                        onTap: () => _showBroilerRecordSalesBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                  ],

                                    const SizedBox(width: 8),
                                    _buildCompactButton(
                                        icon: Icons.money_off_csred_outlined,
                                        label: 'Add Expenses',
                                        color: Colors.amber[900]!,
                                        onTap: () => _showRecordExpenseBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                    const SizedBox(width: 8),
                                    _buildCompactButton(
                                        icon: Icons.heart_broken_outlined,
                                        label: 'Add Mortalities',
                                        color: Colors.red,
                                        onTap: () => _showRecordMortalityBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                        context: context,
                                        isActive: widget.coop.active
                                    ),
                                    if (widget.coop.coopType == 'LAYERS') ...[
                                        const SizedBox(width: 8),
                                        _buildCompactButton(
                                            icon: Icons.egg,
                                            label: 'Record Eggs',
                                            color: const Color(0xFF7C7350),
                                            onTap: () => _showRecordEggsBottomSheet(widget.coop, widget.farm.id, widget.onCoopUpdated),
                                            context: context,
                                            isActive: widget.coop.active,
                                        ),
                                    ] else ...[
                                        const SizedBox(width: 8),
                                        _buildCompactButton(
                                            icon: Icons.monitor_weight_outlined,
                                            label: 'Weight',
                                            color: const Color(0xFF7C7350),
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
                    backgroundColor: Colors.white, // White background
                    foregroundColor: Theme.of(context).primaryColor, // Icon & text color
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
                                color: isActive ? color : Colors.grey,
                            ),
                            const SizedBox(height: 1),
                            Text(
                                label,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis, // handles long labels
                                style: TextStyle(
                                    color: isActive ? Theme.of(context).primaryColor : Colors.grey,
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
                            color: isActive ? color : Colors.grey,
                        ),
                        const SizedBox(height: 1),
                        Text(
                            label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis, // handles long labels
                            style: TextStyle(
                                color: isActive ? Theme.of(context).primaryColor : Colors.grey,
                                fontSize: 8,
                                fontWeight: FontWeight.w400,
                            ),
                        ),
                    ],
                ),
            ),
            backgroundColor: Colors.white,
            side: BorderSide(
                color: isActive
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.4),
            ),
            elevation: 0,
            pressElevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            onPressed: isActive ? onTap : null,
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
        return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.black12, width: 0.3),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Expanded(
                                child: _buildInfoRow(
                                    Icons.fact_check_outlined,
                                    'Number of Chickens',
                                    '${widget.coop.numberOfChickens}',
                                ),
                            ),
                            if(widget.user.farmOwner)...{
                                PopupMenuButton<String>(
                                    icon: Icon(Icons.settings,
                                        color: Theme
                                            .of(context)
                                            .colorScheme
                                            .secondary),
                                    onSelected: (String result) {
                                        _handleMenuSelection(
                                            result, widget.coop, widget.farm.id,
                                            widget.onCoopUpdated);
                                    },
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                    ),
                                    offset: const Offset(0, 50),
                                    color: Colors.white,
                                    elevation: 8,
                                    itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<String>>[
                                        _buildPopupMenuItem(
                                            'updateCoop',
                                            Icons.update,
                                            'Update Coop',
                                            Theme
                                                .of(context)
                                                .colorScheme
                                                .secondary),
                                        _buildPopupMenuItem(
                                            'newBatch',
                                            Icons.clear_all_outlined,
                                            'New Chicken batch',
                                            Colors.deepOrange),
                                        _buildPopupMenuItem(
                                            'deleteCoop',
                                            Icons.delete_outline,
                                            'Delete Coop',
                                            Theme
                                                .of(context)
                                                .colorScheme
                                                .error),
                                    ],
                                ),
                            }
                        ],
                    ),
                    _buildInfoRow(Icons.calendar_today_outlined, 'Chicken Arrival',
                        widget.coop.chickenArrivalDate),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                        Icons.timer_outlined, 'Chicken Age', widget.coop.chickenAge),
                    const SizedBox(height: 5),
                    _buildSalesCardSection(
                        sales: widget.coop.sales,
                        userId: widget.user.id,
                        farmId: widget.farm.id,
                        coopId: widget.coop.id,
                        onCoopDeleted: widget.onCoopUpdated,
                        context: context,
                    ),

                    const SizedBox(height: 5),
                    _buildExpenseCardSection(
                        expenses: widget.coop.expenses,
                        userId: widget.user.id,
                        farmId: widget.farm.id,
                        coopId: widget.coop.id,
                        onCoopDeleted: widget.onCoopUpdated,
                        context: context,
                    ),

                    const SizedBox(height: 5),
                    _buildMortalityCardSection(
                        mortalities: widget.coop.mortalities,
                        userId: widget.user.id,
                        farmId: widget.farm.id,
                        coopId: widget.coop.id,
                        onCoopDeleted: widget.onCoopUpdated,
                        context: context,
                    ),

                    if (widget.coop.coopType == 'LAYERS') ...[
                        const SizedBox(height: 5),
                        _buildEggsRecordCardSection(
                            eggPackagingRecords: widget.coop.eggPackagingRecords,
                            userId: widget.user.id,
                            farmId: widget.farm.id,
                            coopId: widget.coop.id,
                            onCoopDeleted: widget.onCoopUpdated,
                            context: context,
                        ),
                    ],

                ],
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
                    splashColor: Colors.green.withOpacity(0.2),
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
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                                BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
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
                                        color: Colors.green[900],
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
                                                color: Colors.green[100],
                                                borderRadius: BorderRadius.circular(12.0),
                                            ),
                                            child: Text(
                                                'R${totalSaleAmount.toStringAsFixed(2)}',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Arrow at the very end
                                        const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: Colors.green,
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
                                                        color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                                                                color: Theme.of(context).primaryColor,
                                                                letterSpacing: 0.5,
                                                            ),
                                                        ),
                                                    ),

                                                    // Close button aligned to the right
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: const Icon(Icons.close, color: Colors.grey),
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
                                                        colors: [Colors.green.shade800, Colors.green.shade300],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: Colors.green.withOpacity(0.4),
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
                                                            decoration: const BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(
                                                                Icons.attach_money,
                                                                size: 32,
                                                                color: Colors.white,
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
                                                                    duration: const Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            'R${value.toStringAsFixed(2)}',
                                                                            style: const TextStyle(
                                                                                fontSize: 24,
                                                                                color: Colors.white,
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
                                                                        backgroundColor: Colors.green.withOpacity(0.2),
                                                                        child: const Icon(Icons.shopping_cart, color: Colors.green),
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
                                                                                style: TextStyle(fontSize: 10.0, color: Colors.grey[600])),
                                                                        ],
                                                                    ),
                                                                    trailing: Row(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        children: [
                                                                            IconButton(
                                                                                icon: const Icon(Icons.info_outline, color: Colors.blue),
                                                                                onPressed: () {
                                                                                    _showSaleDetailsDialog(context, sale);
                                                                                },
                                                                            ),
                                                                            IconButton(
                                                                                icon: const Icon(Icons.delete, color: Colors.red),
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
                                                            padding: const EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No sales recorded yet.',
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(color: Colors.grey[600]),
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
                    splashColor: Colors.red.withOpacity(0.2),
                    onTap: () {
                        _showMortalityBottomSheet(
                            context, mortalities, userId, farmId, coopId, onCoopDeleted);
                    },
                    child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                                BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
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
                                        color: Colors.deepOrange[900],
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
                                                color: Colors.deepOrange[100],
                                                borderRadius: BorderRadius.circular(12.0),
                                            ),
                                            child: Text(
                                                totalMortalities.toString(),
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.deepOrange,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Arrow at the very end
                                        const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: Colors.green,
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
                                                        color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                                                                color: Theme.of(context).primaryColor,
                                                                letterSpacing: 0.5,
                                                            ),
                                                        ),
                                                    ),
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: const Icon(Icons.close, color: Colors.grey),
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
                                                        colors: [Colors.red.shade800, Colors.red.shade400],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: Colors.red.withOpacity(0.4),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration: const BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(
                                                                Icons.block,
                                                                size: 32,
                                                                color: Colors.white,
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
                                                                    duration: const Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            value.toStringAsFixed(0),
                                                                            style: const TextStyle(
                                                                                fontSize: 24,
                                                                                color: Colors.white,
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
                                                                        backgroundColor: Colors.red.withOpacity(0.2),
                                                                        child: const Icon(Icons.block_outlined,
                                                                            color: Colors.red),
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
                                                                                    color: Colors.grey[600])),
                                                                        ],
                                                                    ),
                                                                    trailing: IconButton(
                                                                        icon: const Icon(Icons.delete, color: Colors.red),
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
                                                            padding: const EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No mortality recorded yet.',
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(color: Colors.grey[600]),
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
                    splashColor: Colors.amber.withOpacity(0.2),
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
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                                BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
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
                                        color: Colors.amber[900],
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
                                                color: Colors.amber[100],
                                                borderRadius: BorderRadius.circular(12.0),
                                            ),
                                            child: Text(
                                                'R${totalExpenses.toStringAsFixed(2)}',
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber,
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Arrow at the very end
                                        const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 18,
                                            color: Colors.green,
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
                                                        color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                                                                color: Theme.of(context).primaryColor,
                                                                letterSpacing: 0.5,
                                                            ),
                                                        ),
                                                    ),
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: const Icon(Icons.close, color: Colors.grey),
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
                                                        colors: [Colors.amber.shade800, Colors.amber.shade300],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: Colors.amber.withOpacity(0.4),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration: const BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(
                                                                Icons.monetization_on,
                                                                size: 32,
                                                                color: Colors.white,
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
                                                                    duration: const Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            'R${value.toStringAsFixed(2)}',
                                                                            style: const TextStyle(
                                                                                fontSize: 24,
                                                                                color: Colors.white,
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
                                                                        backgroundColor: Colors.amber.withOpacity(0.2),
                                                                        child: const Icon(Icons.monetization_on,
                                                                            color: Colors.amber),
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
                                                                                    color: Colors.grey[600])),
                                                                            if (expense.additionalInfo.trim().isNotEmpty)
                                                                            Text(
                                                                                'Additional Info: ${expense.additionalInfo}',
                                                                                style: TextStyle(
                                                                                    fontSize: 10.0, color: Colors.grey[600]),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                    trailing: IconButton(
                                                                        icon: const Icon(Icons.delete, color: Colors.red),
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
                                                            padding: const EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No expenses recorded yet.',
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodyMedium
                                                                    ?.copyWith(color: Colors.grey[600]),
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
            splashColor: Colors.orange.withOpacity(0.2),
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
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
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
                                color: const Color(0xFF7C7350),
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
                                        color: Color(0xFFF8EEC8),
                                        borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: Text(
                                        totalEggs.toString(),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF7C7350),
                                        ),
                                    ),
                                ),
                                const SizedBox(width: 8),

                                // Arrow at the very end
                                const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 18,
                                    color: Colors.green,
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
                                                        color: Theme.of(context).primaryColor.withOpacity(0.3),
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
                                                                color: Theme.of(context).primaryColor,
                                                            ),
                                                        ),
                                                    ),
                                                    Positioned(
                                                        right: 0,
                                                        child: IconButton(
                                                            icon: const Icon(Icons.close, color: Colors.grey),
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
                                                        colors: [Color(0xFF7C7350), Color(
                                                                0xFFEAD47E)],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(16),
                                                    boxShadow: [
                                                        BoxShadow(
                                                            color: Colors.orange.withOpacity(0.4),
                                                            blurRadius: 12,
                                                            offset: const Offset(0, 6),
                                                        ),
                                                    ],
                                                ),
                                                child: Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.all(12),
                                                            decoration: const BoxDecoration(
                                                                color: Colors.white24,
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child: const Icon(
                                                                Icons.egg,
                                                                size: 32,
                                                                color: Colors.white,
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
                                                                    duration: const Duration(seconds: 1),
                                                                    builder: (context, value, child) {
                                                                        return Text(
                                                                            value.toStringAsFixed(0),
                                                                            style: const TextStyle(
                                                                                fontSize: 24,
                                                                                color: Colors.white,
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
                                                                        backgroundColor: Colors.orange.withOpacity(0.2),
                                                                        child: const Icon(Icons.egg, color: Colors.orange),
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
                                                                        icon: const Icon(Icons.delete, color: Colors.red),
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
                                                            padding: const EdgeInsets.all(20.0),
                                                            child: Text(
                                                                'No egg packaging records yet.',
                                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                                    color: Colors.grey[600],
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
                                foregroundColor: Theme.of(context).primaryColor,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                                Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                        ),
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.deepOrange,
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
        final saleDate = DateFormat('yyyy-MM-dd').format(
            DateTime.parse(sale.saleDate),
        );

        showDialog(
            context: context,
            builder: (context) {
                return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15.0),
                    ),
                    title: Row(
                        children: [
                            Icon(Icons.receipt_long,
                                color: Theme.of(context).primaryColor, size: 25),
                            const SizedBox(width: 8.0),
                            Text('Sale Details',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor)),
                        ],
                    ),
                    content: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                _buildDetailRow(Icons.person, 'Buyer:', sale.buyerName),
                                if (sale.numberOfChickensSold > 0)
                                _buildDetailRow(Icons.shopping_bag, 'Chickens Sold:',
                                    '${sale.numberOfChickensSold}'),
                                if (sale.numberOfDozensSold > 0)
                                _buildDetailRow(Icons.shopping_bag, 'Number Of Dozens Sold:',
                                    '${sale.numberOfDozensSold}'),
                                if (sale.salePricePerDozen > 0)
                                _buildDetailRow(Icons.attach_money, 'Sale Price Per Dozen:',
                                    'R${sale.salePricePerDozen}'),
                                if (sale.salePricePerChicken > 0)
                                _buildDetailRow(Icons.attach_money, 'Price per Chicken:',
                                    'R${sale.salePricePerChicken}'),
                                _buildDetailRow(Icons.money, 'Total Sale Amount:',
                                    'R${sale.totalSaleAmount}'),
                                _buildDetailRow(
                                    sale.paymentStatus.toLowerCase() == 'paid'
                                        ? Icons.check_circle
                                        : Icons.error,
                                    'Payment Status:',
                                    sale.paymentStatus,
                                    valueColor: sale.paymentStatus.toLowerCase() == 'paid'
                                        ? Colors.green
                                        : Colors.red,
                                ),
                                _buildDetailRow(Icons.calendar_today, 'Sale Date:', saleDate),
                            ],
                        ),
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                                'Close',
                                style: TextStyle(color: Theme.of(context).primaryColor),
                            ),
                        ),
                    ],
                );
            },
        );
    }

    Widget _buildDetailRow(IconData icon, String label, String value,
        {Color? valueColor}) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Icon(icon, size: 20.0, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8.0),
                    Expanded(
                        child: RichText(
                            text: TextSpan(
                                text: '$label ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, color: Colors.black),
                                children: [
                                    TextSpan(
                                        text: value,
                                        style: TextStyle(
                                            fontWeight: FontWeight.normal,
                                            color: valueColor ?? Colors.black,
                                        ),
                                    ),
                                ],
                            ),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
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
                                                                                child: const Text(
                                                                                    'Confirm',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
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
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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
                    Icon(icon, size: 20, color: Theme.of(context).primaryColor),
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
                            color: Theme.of(context).primaryColor,
                        ),
                    ),
                    content: Text(content),
                    actions: <Widget>[
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).primaryColor,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                                Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                        ),
                        TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.deepOrange,
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
                                        Common.buildSnackBar(response.message, Colors.red),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
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

                                                                                    final response = await service.updateFarmCoop(
                                                                                        farmId: farmId,
                                                                                        coopId: coop.id,
                                                                                        coopName: coopName,
                                                                                        coopType: coopType,
                                                                                        growthPhase: growthPhase,
                                                                                        numberOfChickens: numberOfChickens,
                                                                                        chickenArrivalDate: chickenArrivalDate?.toIso8601String(),
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
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                    label: 'Number Of Chickens Sold',
                                                                    icon: Icons.fact_check_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    numberOfChickensSold = int.tryParse(value) ?? 0,
                                                                    validator: (value) {
                                                                        final number = int.tryParse(value!);
                                                                        return number == null || number <= 0
                                                                            ? 'Please enter a valid number'
                                                                            : null;
                                                                    },
                                                                    context: context,
                                                                ),

                                                                const SizedBox(height: 22),

                                                                Common.buildTextField(
                                                                    label: 'Sale Price Per Chicken',
                                                                    icon: Icons.attach_money_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    salePricePerChicken = double.tryParse(value) ?? 0,
                                                                    validator: (value) {
                                                                        final number = double.tryParse(value!);
                                                                        return number == null || number <= 0
                                                                            ? 'Please enter a valid number'
                                                                            : null;
                                                                    },
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
                                                                        return Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                                Common.buildDateField(
                                                                                    context: context,
                                                                                    label: 'Sale Date',
                                                                                    date: saleDate,
                                                                                    hasError: hasError, // Pass error status
                                                                                    onDateSelected: (date) {
                                                                                        setModalState(() {
                                                                                                saleDate = date;
                                                                                                field.didChange(date);
                                                                                            });
                                                                                    },
                                                                                ),
                                                                                if (hasError)
                                                                                const Padding(
                                                                                    padding: EdgeInsets.only(top: 6),
                                                                                    child: Text(
                                                                                        'Please select a sale date',
                                                                                        style: TextStyle(color: Colors.red, fontSize: 12),
                                                                                    ),
                                                                                ),
                                                                            ],
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
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

                                                                                    if (!isFormValid || !isPaymentStatusValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

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
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                    label: 'Number Of Dozens Sold',
                                                                    icon: Icons.fact_check_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    numberOfDozensSold = int.tryParse(value) ?? 0,
                                                                    validator: (value) {
                                                                        final number = int.tryParse(value!);
                                                                        return number == null || number <= 0
                                                                            ? 'Please enter a valid number'
                                                                            : null;
                                                                    },
                                                                    context: context,
                                                                ),
                                                                const SizedBox(height: 22),
                                                                Common.buildTextField(
                                                                    label: 'Sale Price Per Dozen',
                                                                    icon: Icons.fact_check_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    salePricePerDozen = double.tryParse(value) ?? 0,
                                                                    validator: (value) {
                                                                        final number = int.tryParse(value!);
                                                                        return number == null || number <= 0
                                                                            ? 'Please enter a valid number'
                                                                            : null;
                                                                    },
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
                                                                        return Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                                Common.buildDateField(
                                                                                    context: context,
                                                                                    label: 'Sale Date',
                                                                                    date: saleDate,
                                                                                    hasError: hasError, // Pass error status
                                                                                    onDateSelected: (date) {
                                                                                        setModalState(() {
                                                                                                saleDate = date;
                                                                                                field.didChange(date);
                                                                                            });
                                                                                    },
                                                                                ),
                                                                                if (hasError)
                                                                                const Padding(
                                                                                    padding: EdgeInsets.only(top: 6),
                                                                                    child: Text(
                                                                                        'Please select a sale date',
                                                                                        style: TextStyle(color: Colors.red, fontSize: 12),
                                                                                    ),
                                                                                ),
                                                                            ],
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
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

                                                                                    if (!isFormValid || !isPaymentStatusValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

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
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                    label: 'Number of boxes',
                                                                    icon: Icons.library_books_sharp,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    numberOfBoxes = int.tryParse(value) ?? 0,
                                                                    validator: (value) {
                                                                        final number = int.tryParse(value!);
                                                                        return number == null || number <= 0
                                                                            ? 'Please enter a valid number'
                                                                            : null;
                                                                    },
                                                                    context: context,
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                onPressed: () async {

                                                                                    final isFormValid = formKey.currentState!.validate();

                                                                                    setModalState(() {
                                                                                            showEggSizeError = eggSize == null;
                                                                                            showBoxSizeError = boxSize == null;
                                                                                        });

                                                                                    if (!isFormValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

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
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                    label: 'Number Of Deaths',
                                                                    icon: Icons.fact_check_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    numberOfDeaths = int.tryParse(value) ?? 0,
                                                                    validator: (value) {
                                                                        final number = int.tryParse(value!);
                                                                        return number == null || number <= 0
                                                                            ? 'Please enter a valid number'
                                                                            : null;
                                                                    },
                                                                    context: context,
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
                                                                        final hasError = field.hasError;
                                                                        return Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                                Common.buildDateField(
                                                                                    context: context,
                                                                                    label: 'When did this occurred?',
                                                                                    date: dateOccurred,
                                                                                    hasError: hasError, // Pass error status
                                                                                    onDateSelected: (date) {
                                                                                        setModalState(() {
                                                                                                dateOccurred = date;
                                                                                                field.didChange(date);
                                                                                            });
                                                                                    },
                                                                                ),
                                                                                if (hasError)
                                                                                const Padding(
                                                                                    padding: EdgeInsets.only(top: 6),
                                                                                    child: Text(
                                                                                        'Please select a sale date',
                                                                                        style: TextStyle(color: Colors.red, fontSize: 12),
                                                                                    ),
                                                                                ),
                                                                            ],
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                onPressed: () async {

                                                                                    hasSubmitted = true;
                                                                                    final isFormValid = formKey.currentState!.validate();

                                                                                    setModalState(() {
                                                                                            isSaleDateError = dateOccurred == null;
                                                                                        });

                                                                                    if (!isFormValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

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
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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
                                                        color: Theme.of(context).primaryColor,
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
                                                        color: Theme.of(context).primaryColor,
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
                                                                Common.buildTextField(
                                                                    label: 'Amount',
                                                                    icon: Icons.fact_check_outlined,
                                                                    keyboardType: TextInputType.number,
                                                                    onChanged: (value) =>
                                                                    amount = double.tryParse(value) ?? 0,
                                                                    validator: (value) {
                                                                        final number = int.tryParse(value!);
                                                                        return number == null || number <= 0
                                                                            ? 'Please enter a valid number'
                                                                            : null;
                                                                    },
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
                                                                        return Column(
                                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                                            children: [
                                                                                Common.buildDateField(
                                                                                    context: context,
                                                                                    label: 'Date of Expense',
                                                                                    date: expenseDate,
                                                                                    onDateSelected: (date) {
                                                                                        setState(() {
                                                                                                expenseDate = date;
                                                                                                field.didChange(date);
                                                                                            });
                                                                                    },
                                                                                    hasError: isSaleDateError,
                                                                                ),
                                                                                if (isSaleDateError)
                                                                                const Padding(
                                                                                    padding: EdgeInsets.only(top: 6),
                                                                                    child: Text(
                                                                                        'Please select a sale date',
                                                                                        style: TextStyle(color: Colors.red, fontSize: 12),
                                                                                    ),
                                                                                ),
                                                                            ],
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
                                                                                    backgroundColor: Theme.of(context).primaryColor,
                                                                                    elevation: 3,
                                                                                    shape: RoundedRectangleBorder(
                                                                                        borderRadius: BorderRadius.circular(12),
                                                                                    ),
                                                                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                                                                ),
                                                                                onPressed: () async {

                                                                                    hasSubmitted = true;
                                                                                    final isFormValid = formKey.currentState!.validate();

                                                                                    setModalState(() {
                                                                                            isSaleDateError = expenseDate == null;
                                                                                        });

                                                                                    if (!isFormValid) return;

                                                                                    await Common.showLottieDialog(
                                                                                        context,
                                                                                        lottiePath: 'assets/lottie/loading_animation.json',
                                                                                    );

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
                                                                                            autoCloseAfter: const Duration(seconds: 5),
                                                                                        );
                                                                                    }
                                                                                },
                                                                                child: const Text(
                                                                                    'Submit',
                                                                                    style: TextStyle(
                                                                                        color: Colors.white,
                                                                                        fontWeight: FontWeight.w600,
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ),
                                                                        const SizedBox(width: 12),
                                                                        OutlinedButton(
                                                                            style: OutlinedButton.styleFrom(
                                                                                foregroundColor: Colors.red,
                                                                                side: const BorderSide(color: Colors.red),
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

    void _showErrorSnackBar(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, Colors.red),
        );
    }

    void _showSuccessSnackBar(String message) {
        ScaffoldMessenger.of(context).showSnackBar(
            Common.buildSnackBar(message, Colors.green),
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
