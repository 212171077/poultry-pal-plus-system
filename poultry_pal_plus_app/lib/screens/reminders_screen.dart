import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:lottie/lottie.dart';

import '../models/coop.dart';
import '../models/farm.dart';
import '../models/growing_phase.dart';
import '../models/transition_coop.dart';
import '../models/user.dart';
import '../service/poultry_pal_service.dart';
import 'common.dart';

class RemindersScreen extends StatefulWidget {
    final Farm farm;
    final User user;
    final VoidCallback onCoopUpdated;

    const RemindersScreen(
    {super.key,
        required this.farm,
        required this.user,
        required this.onCoopUpdated});

    @override
    State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
    @override
    Widget build(BuildContext context) {
        final sortedCoops = [...widget.farm.coops]..sort((a, b) {
                if (a.active == b.active) return 0; // Keep relative order if both same
                return a.active ? -1 : 1; // Active first
            });
        return Scaffold(
            body: widget.farm.coops.isEmpty
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                            'No reminders yet! Add your coop(s) on the home page to start '
                            'tracking tasks like feeding, vaccinations, '
                            'and more. Your reminders will appear here to '
                            'help manage your poultry effectively.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18,
                                color: AppColors.textTertiaryLight,
                                fontWeight: FontWeight.w500,
                            ),
                        ),
                    ),
                )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sortedCoops.map((coop) {
                                return ExpandableCoopCard(
                                    coop: coop,
                                    farm: widget.farm,
                                    user: widget.user,
                                    onCoopUpdated: widget.onCoopUpdated);
                            }).toList(),
                    ),
                ),
        );
    }
}

class ExpandableCoopCard extends StatefulWidget {
    final Coop coop;
    final Farm farm;
    final User user;
    final VoidCallback onCoopUpdated;

    const ExpandableCoopCard(
    {super.key,
        required this.coop,
        required this.farm,
        required this.user,
        required this.onCoopUpdated});

    @override
    State<ExpandableCoopCard> createState() =>
    _ExpandableCoopCardState();
}

class _ExpandableCoopCardState
    extends State<ExpandableCoopCard> {
    bool isExpanded = false;

    @override
    Widget build(BuildContext context) {
        final overdueTasks = widget.coop.reminder.overdueTasks;
        final upcomingReminders = widget.coop.reminder.upcomingReminders;
        final VoidCallback onCoopUpdated = widget.onCoopUpdated;
        final hasPhaseTransition =
            widget.coop.phaseTransition.currentPhase != GrowingPhase.NONE;
        PoultryPalService service = PoultryPalService();
        bool isSending = false;
        bool isSuccess = false;

        return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(vertical: 10.0),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.black12, width: 0.3),
                        gradient: LinearGradient(
                            colors: isExpanded
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
                borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
                children: [
                    GestureDetector(
                        onTap: () {
                            setState(() {
                                    isExpanded = !isExpanded;
                                });
                        },
                        child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            decoration: const BoxDecoration(
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(15),
                                    topRight: Radius.circular(15),
                                ),
                            ),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                            Hero(
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
                                            if (overdueTasks.isNotEmpty)
                                            Positioned(
                                                top: -10,
                                                right: 14, // move closer to the avatar edge
                                                child: _buildNotificationIcon(
                                                    context,
                                                    icon: Icons.warning_amber_rounded,
                                                    count: overdueTasks.length,
                                                    color: AppColors.errorLight,
                                                    hasPhaseTransition: false,
                                                ),
                                            ),
                                            if (upcomingReminders.isNotEmpty)
                                            Positioned(
                                                top: -0,
                                                right: -4, // closer to previous icon
                                                child: _buildNotificationIcon(
                                                    context,
                                                    icon: Icons.notifications_active_rounded,
                                                    count: upcomingReminders.length,
                                                    color: AppColors.infoLight,
                                                    hasPhaseTransition: hasPhaseTransition,
                                                ),
                                            ),
                                            // Online/offline status dot
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
                                    )
                                    ,

                                    const SizedBox(width: 12), // space between avatar and text

                                    // Flexible text column
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    widget.coop.coopName,
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: AppColors.adaptivePrimary(context),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                                Text(
                                                                    "${widget.coop.coopType.toLowerCase().capitalize()} (${widget.coop.growthPhase.value})",
                                                                    style: TextStyle(
                                                                        fontSize: 12,
                                                                        color: AppColors.textSecondary(context),
                                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                        ),
                                    ),

                                    const SizedBox(width: 4),

                                    // Expand/collapse icon
                                    IconButton(
                                        icon: Icon(
                                            isExpanded ? Icons.expand_less : Icons.expand_more,
                                            size: 40,
                                            color: AppColors.success,
                                        ),
                                        onPressed: () {
                                            setState(() {
                                                    isExpanded = !isExpanded;
                                                });
                                        },
                                    ),
                                ],
                            ),
                        ),
                    ),
                    if (isExpanded)
                    TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 300),
                        builder: (context, value, child) {
                            return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)), // Slide up effect
                                    child: child,
                                ),
                            );
                        },
                        child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(16.0),
                                border: Border.all(color: Colors.black12, width: 0.3),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                    StatefulBuilder(
                                        builder: (context, setState) {
                                            Future<void> handleSend() async {
                                                setState(() {
                                                        isSending = true;
                                                        isSuccess = false;
                                                    });

                                                try {
                                                    final success = await service.sendScheduleEmail(
                                                        userId: widget.user.id,
                                                        farmId: widget.farm.id,
                                                        coopId: widget.coop.id,
                                                    );

                                                    setState(() {
                                                            isSending = false;
                                                            isSuccess = success;
                                                        });

                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                            content: Text(
                                                                success
                                                                    ? 'Schedule sent successfully, please check your email.'
                                                                    : 'Failed to send schedule.',
                                                            ),
                                                            backgroundColor: success ? AppColors.success : AppColors.error,
                                                            behavior: SnackBarBehavior.floating,
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(10),
                                                            ),
                                                            margin: const EdgeInsets.all(16),
                                                        ),
                                                    );
                                                } catch (e) {
                                                    setState(() {
                                                            isSending = false;
                                                        });

                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                            content: Text('❗ Something went wrong.'),
                                                            backgroundColor: AppColors.error,
                                                            behavior: SnackBarBehavior.floating,
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.all(Radius.circular(10)),
                                                            ),
                                                            margin: EdgeInsets.all(16),
                                                        ),
                                                    );
                                                }

                                                await Future.delayed(const Duration(seconds: 2));
                                                setState(() => isSuccess = false);
                                            }

                                            return widget.coop.active
                                                ? Align(
                                                    alignment: Alignment.centerLeft,
                                                    child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 300),
                                                        child: ElevatedButton(
                                                            onPressed: isSending ? null : handleSend,
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
                                                            child: Row(
                                                                mainAxisSize: MainAxisSize.min,
                                                                children: [
                                                                    SizedBox(
                                                                        width: 22,
                                                                        height: 22,
                                                                        child: isSending
                                                                            ? Lottie.asset(
                                                                                'assets/lottie/email_send.json',
                                                                                fit: BoxFit.contain,
                                                                                repeat: true,
                                                                                addRepaintBoundary: true,
                                                                            )
                                                                            : isSuccess
                                                                                ? Lottie.asset(
                                                                                    'assets/lottie/success_check.json',
                                                                                    fit: BoxFit.contain,
                                                                                    repeat: false,
                                                                                    addRepaintBoundary: true,
                                                                                )
                                                                                : Icon(
                                                                                    Icons.email_outlined,
                                                                                    size: 18,
                                                                                    color: AppColors.adaptivePrimary(context),
                                                                                ),
                                                                    ),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                        isSending
                                                                            ? 'Sending schedule...'
                                                                            : isSuccess
                                                                                ? 'Schedule Sent!'
                                                                                : 'Send Schedule',
                                                                        style: TextStyle(
                                                                            fontSize: 13,
                                                                            color: AppColors.adaptivePrimary(context),
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
                                                        ),
                                                    ),
                                                )
                                                : const SizedBox.shrink(); // Empty widget if inactive

                                        },
                                    ),

                                    const SizedBox(height: 5),

                                    if (hasPhaseTransition)
                                    Container(
                                        margin: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                            color: AppColors.surface(context),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                                color: AppColors.warning.withValues(alpha: 0.45),
                                                width: 1,
                                            ),
                                            boxShadow: [
                                                BoxShadow(
                                                    color: AppColors.warning.withValues(alpha: 0.10),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 3),
                                                ),
                                            ],
                                        ),
                                        child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Column(
                                                children: [
                                                    // ── Header bar ──────────────────────────────
                                                    Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 16, vertical: 12),
                                                        decoration: BoxDecoration(
                                                            color: AppColors.warning.withValues(alpha: 0.10),
                                                            border: Border(
                                                                bottom: BorderSide(
                                                                    color: AppColors.warning.withValues(alpha: 0.25),
                                                                ),
                                                            ),
                                                        ),
                                                        child: Row(
                                                            children: [
                                                                Container(
                                                                    padding: const EdgeInsets.all(6),
                                                                    decoration: BoxDecoration(
                                                                        color: AppColors.warning.withValues(alpha: 0.18),
                                                                        borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                    child: const Icon(Icons.sync_rounded,
                                                                        color: AppColors.warning, size: 16),
                                                                ),
                                                                const SizedBox(width: 10),
                                                                Expanded(
                                                                    child: Text(
                                                                        'Phase Transition Ready',
                                                                        style: TextStyle(
                                                                            fontSize: 14,
                                                                            fontWeight: FontWeight.w700,
                                                                            color: AppColors.textPrimary(context),
                                                                        ),
                                                                    ),
                                                                ),
                                                                GestureDetector(
                                                                    onTap: () => _showPhaseTransitionInfoPopup(context),
                                                                    child: Container(
                                                                        padding: const EdgeInsets.all(5),
                                                                        decoration: BoxDecoration(
                                                                            color: AppColors.info.withValues(alpha: 0.12),
                                                                            borderRadius: BorderRadius.circular(7),
                                                                        ),
                                                                        child: const Icon(Icons.info_outline_rounded,
                                                                            color: AppColors.info, size: 17),
                                                                    ),
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                    // ── Body ────────────────────────────────────
                                                    Padding(
                                                        padding: const EdgeInsets.all(16),
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                Text(
                                                                    'Your chickens are ready to move to the next growth phase.',
                                                                    style: TextStyle(
                                                                        fontSize: 12,
                                                                        color: AppColors.textSecondary(context),
                                                                        height: 1.4,
                                                                    ),
                                                                ),
                                                                const SizedBox(height: 14),
                                                                // Phase flow chips
                                                                Row(
                                                                    children: [
                                                                        Expanded(
                                                                            child: _buildPhaseChip(
                                                                                context,
                                                                                label: widget.coop.phaseTransition.currentPhase.value,
                                                                                color: AppColors.success,
                                                                                isCurrent: true,
                                                                            ),
                                                                        ),
                                                                        Padding(
                                                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                                                            child: Icon(
                                                                                Icons.arrow_forward_rounded,
                                                                                color: AppColors.warning,
                                                                                size: 22,
                                                                            ),
                                                                        ),
                                                                        Expanded(
                                                                            child: _buildPhaseChip(
                                                                                context,
                                                                                label: widget.coop.phaseTransition.newPhase.value,
                                                                                color: AppColors.warning,
                                                                                isCurrent: false,
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                                const SizedBox(height: 14),
                                                                SizedBox(
                                                                    width: double.infinity,
                                                                    child: ElevatedButton.icon(
                                                                        onPressed: () => _showConfirmPhaseTransitionDialog(
                                                                            context,
                                                                            widget.coop.phaseTransition.currentPhase.value,
                                                                            widget.coop.phaseTransition.newPhase.value,
                                                                            widget.user.id,
                                                                            widget.farm.id,
                                                                            widget.coop.id,
                                                                            widget.coop.phaseTransition.transitionCoops,
                                                                            () => widget.onCoopUpdated(),
                                                                        ),
                                                                        icon: const Icon(Icons.sync_rounded, size: 18),
                                                                        label: const Text(
                                                                            'Confirm Transition',
                                                                            style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w600,
                                                                            ),
                                                                        ),
                                                                        style: ElevatedButton.styleFrom(
                                                                            backgroundColor: AppColors.warning,
                                                                            foregroundColor: Colors.white,
                                                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                                                            elevation: 0,
                                                                            shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(10),
                                                                            ),
                                                                        ),
                                                                    ),
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                    ),
                                    if (overdueTasks.isNotEmpty) ...[
                                        _buildSectionTitle(
                                            context, 'Overdue Tasks', AppColors.error),
                                        _buildTaskList(
                                            context,
                                            overdueTasks,
                                            widget.coop,
                                            widget.farm,
                                            widget.user,
                                            AppColors.error,
                                            onCoopUpdated),
                                    ],
                                    if (upcomingReminders.isNotEmpty) ...[
                                        SizedBox(height: overdueTasks.isNotEmpty ? 20 : 0),
                                        _buildSectionTitle(
                                            context, 'Upcoming Reminders', AppColors.adaptivePrimary(context)),
                                        _buildTaskList(
                                            context,
                                            upcomingReminders,
                                            widget.coop,
                                            widget.farm,
                                            widget.user,
                                            AppColors.adaptivePrimary(context),
                                            onCoopUpdated,
                                        ),
                                    ],
                                    if (upcomingReminders.isEmpty && overdueTasks.isEmpty) ...[
                                        const SizedBox(height: 5),
                                        const Center(
                                            child: Padding(
                                                padding: EdgeInsets.all(8.0),
                                                child: Center(
                                                    child: Text(
                                                        'No reminders yet! your upcoming and overdue reminders will appear here',
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                            fontSize: 14,
                                                            color: AppColors.textTertiaryLight,
                                                            fontWeight: FontWeight.w500,
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        )
                                    ],
                                ],
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildPhaseChip(BuildContext context, {
        required String label,
        required Color color,
        required bool isCurrent,
    }) {
        return Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
                color: color.withValues(alpha: isCurrent ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Icon(
                        isCurrent ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: color,
                        size: 15,
                    ),
                    const SizedBox(height: 5),
                    Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                        isCurrent ? 'Current' : 'Next',
                        style: TextStyle(
                            fontSize: 9,
                            color: color.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildSectionTitle(BuildContext context, String title, Color color) {
        final bool isOverdue = title.toLowerCase().contains('overdue');
        return Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Row(
                children: [
                    Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.notifications_active_rounded,
                            color: color,
                            size: 15,
                        ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                        title,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.2,
                        ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Divider(
                            color: color.withValues(alpha: 0.3),
                            thickness: 1,
                            height: 1,
                        ),
                    ),
                ],
            ),
        );
    }

    Widget _buildTaskList(
        BuildContext context,
        List<Map<String, dynamic>> tasks,
        Coop coop,
        Farm farm,
        User user,
        Color iconColor,
        VoidCallback onCoopUpdated) {
        return Column(
            children: tasks.map((task) {
                    final details = task['details'];
                    final taskName = _getTaskName(task);

                    return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
                        color: AppColors.surface(context),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: iconColor.withValues(alpha: 0.45),
                                width: 1,
                            ),
                        ),
                        child: Padding(
                            padding:
                            const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                    Text(
                                        task['icon'] ?? '❓',
                                        style: TextStyle(fontSize: 30, color: iconColor),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    '${task['type']}: ${taskName ?? 'Unknown Task'}',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                    'Due Date: ${details?['dueDate'] ?? 'Unknown Date'}',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: AppColors.textSecondary(context),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                        ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                        icon: Icon(Icons.info_outline, color: iconColor),
                                        onPressed: details != null
                                            ? () => _showDetailsPopup(context, task['type'], details)
                                            : null,
                                        padding: EdgeInsets.zero, // Reduce spacing around icon
                                        constraints: const BoxConstraints(),
                                    ),
                                    PopupMenuButton<String>(
                                        icon: const Icon(Icons.settings, color: AppColors.success),
                                        padding: EdgeInsets.zero,
                                        // Reduce spacing around icon
                                        constraints: const BoxConstraints(),
                                        onSelected: (value) {
                                            switch (value) {
                                                case 'Completed':
                                                    _showUpdateReminderDialog(context, task, 'Completed',
                                                        user.id, farm.id, coop.id, onCoopUpdated);
                                                    break;
                                                case 'Not Applicable':
                                                    _showUpdateReminderDialog(
                                                        context,
                                                        task,
                                                        'Not Applicable',
                                                        user.id,
                                                        farm.id,
                                                        coop.id,
                                                        onCoopUpdated);
                                                    break;
                                                case 'Remove Task':
                                                    _showUpdateReminderDialog(
                                                        context,
                                                        task,
                                                        'Remove Task',
                                                        user.id,
                                                        farm.id,
                                                        coop.id,
                                                        onCoopUpdated);
                                                    break;
                                            }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                            const PopupMenuItem(
                                                value: 'Completed',
                                                child: Row(
                                                    children: [
                                                        Icon(Icons.check_circle, color: AppColors.success),
                                                        SizedBox(width: 10),
                                                        Text('Completed',
                                                            style: TextStyle(fontSize: 14)),
                                                    ],
                                                ),
                                            ),
                                            const PopupMenuItem(
                                                value: 'Not Applicable',
                                                child: Row(
                                                    children: [
                                                        Icon(Icons.cancel, color: AppColors.secondary),
                                                        SizedBox(width: 10),
                                                        Text('Not Applicable',
                                                            style: TextStyle(fontSize: 14)),
                                                    ],
                                                ),
                                            ),
                                            const PopupMenuItem(
                                                value: 'Remove Task',
                                                child: Row(
                                                    children: [
                                                        Icon(Icons.delete, color: AppColors.error),
                                                        SizedBox(width: 10),
                                                        Text('Remove Task',
                                                            style: TextStyle(fontSize: 14)),
                                                    ],
                                                ),
                                            ),
                                        ]),
                                ],
                            ),
                        ),
                    );
                }).toList(),
        );
    }

    void _showUpdateReminderDialog(
        BuildContext context,
        Map<String, dynamic> task,
        String action,
        String userId,
        String farmId,
        String coopId,
        VoidCallback onCoopUpdated,
    ) {
        final TextEditingController actionCommentController =
            TextEditingController();
        PoultryPalService service = PoultryPalService();
        showDialog(
            context: context,
            builder: (BuildContext context) {
                return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Row(
                        children: [
                            Text(
                                'Update Reminder',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                            ),
                        ],
                    ),
                    content: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                const Text(
                                    'Action: ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600),
                                ),
                                Text(
                                    action,
                                    overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                    'Reminder: ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600),
                                ),
                                Text(
                                    task['type'] + ": " + _getTaskName(task) ?? 'Unknown',
                                    overflow: TextOverflow.visible,
                                ),

                                const SizedBox(height: 15),
                                // Action Comment
                                const Text(
                                    'Add Comment (Optional):',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                    controller: actionCommentController,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                        hintText: 'Add your comment...',
                                        hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                        ),
                                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        filled: true,
                                    ),
                                ),
                            ],
                        ),
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.error)),
                        ),
                        ElevatedButton(
                            onPressed: () async {
                                final details = task['details'];
                                final comment = actionCommentController.text;
                                final reminderType = task['type'];
                                final response = await service.updateReminder(
                                    id: details['id'],
                                    updatedByUserId: userId,
                                    farmId: farmId,
                                    coopId: coopId,
                                    reminderType: reminderType,
                                    action: action,
                                    actionComment: comment,
                                );

                                response.success
                                    ? _showSuccessSnackBar(
                                        reminderType + " reminder updated successful",
                                        onCoopUpdated,
                                        context)
                                    : _showErrorSnackBar(response.message, context);
                                Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.adaptivePrimary(context),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                                'Submit',
                                style: TextStyle(color: AppColors.surfaceLight),
                            ),
                        ),
                    ],
                );
            },
        );
    }

    void _showConfirmPhaseTransitionDialog(
        BuildContext context,
        String currentPhase,
        String newPhase,
        String userId,
        String farmId,
        String coopId,
        List<TransitionCoop> transitionCoops,
        VoidCallback onCoopUpdated,
    ) {
        PoultryPalService service = PoultryPalService();
        String? selectedCoopId; // To store the selected coop ID // To store the selected coop ID
        bool useCurrentCoop = false;
        bool showValidationError = false;

        var list = transitionCoops
            .map((coop) => DropdownMenuItem<String>(
                    value: coop.id,
                    child: Text(coop.displayName),
                ))
            .toList();

        showDialog(
            context: context,
            builder: (BuildContext context) {
                return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                        return AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                            ),
                            titlePadding: EdgeInsets.zero,
                            title: Container(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                                decoration: BoxDecoration(
                                    color: AppColors.warning.withValues(alpha: 0.10),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                    border: Border(
                                        bottom: BorderSide(
                                            color: AppColors.warning.withValues(alpha: 0.25),
                                        ),
                                    ),
                                ),
                                child: Row(
                                    children: [
                                        Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                                color: AppColors.warning.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.sync_rounded,
                                                color: AppColors.warning, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                            child: Text(
                                                'Confirm Phase Transition',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 17,
                                                ),
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                            content: SingleChildScrollView(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        // Phase flow summary
                                        Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                                            decoration: BoxDecoration(
                                                color: AppColors.surfaceVariant(context),
                                                borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                                children: [
                                                    Expanded(
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                                Text('Current Phase',
                                                                    style: TextStyle(
                                                                        fontSize: 10,
                                                                        color: AppColors.textTertiary(context),
                                                                        fontWeight: FontWeight.w500,
                                                                    )),
                                                                const SizedBox(height: 3),
                                                                Text(currentPhase,
                                                                    style: const TextStyle(
                                                                        fontSize: 13,
                                                                        fontWeight: FontWeight.w700,
                                                                        color: AppColors.success,
                                                                    )),
                                                            ],
                                                        ),
                                                    ),
                                                    const Icon(Icons.arrow_forward_rounded,
                                                        color: AppColors.warning, size: 20),
                                                    Expanded(
                                                        child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.end,
                                                            children: [
                                                                Text('New Phase',
                                                                    style: TextStyle(
                                                                        fontSize: 10,
                                                                        color: AppColors.textTertiary(context),
                                                                        fontWeight: FontWeight.w500,
                                                                    )),
                                                                const SizedBox(height: 3),
                                                                Text(newPhase,
                                                                    style: const TextStyle(
                                                                        fontSize: 13,
                                                                        fontWeight: FontWeight.w700,
                                                                        color: AppColors.warning,
                                                                    )),
                                                            ],
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        const SizedBox(height: 16),
                                        if (list.isNotEmpty) ...[
                                            Text(
                                                'Select Destination Coop',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.textSecondary(context),
                                                    fontSize: 13,
                                                ),
                                            ),
                                            const SizedBox(height: 6),
                                        ],
                                        list.isNotEmpty
                                            ? Container(
                                                decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: showValidationError &&
                                                            selectedCoopId == null &&
                                                            !useCurrentCoop
                                                            ? AppColors.error
                                                            : Colors.transparent,
                                                    ),
                                                    borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Common.buildDropdown(
                                                    selectedValue:
                                                    useCurrentCoop ? null : selectedCoopId,
                                                    items: list,
                                                    onChanged: (value) {
                                                        setState(() {
                                                                selectedCoopId = value;
                                                                if (value != null) {
                                                                    useCurrentCoop = false;
                                                                    showValidationError = false;
                                                                }
                                                            });
                                                    },
                                                    context: context,
                                                    hintText: 'Select a coop',
                                                ),
                                            )
                                            : Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color: AppColors.info.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(
                                                        color: AppColors.info.withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                        const Icon(Icons.info_outline_rounded,
                                                            color: AppColors.info, size: 16),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                            child: Text(
                                                                'No suitable coop is available. Add a new coop on the home page, or re-use the current coop below.',
                                                                style: TextStyle(
                                                                    fontSize: 12,
                                                                    color: AppColors.textSecondary(context),
                                                                    height: 1.4,
                                                                ),
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        const SizedBox(height: 12),
                                        // Re-use current coop checkbox
                                        GestureDetector(
                                            onTap: () {
                                                setState(() {
                                                        useCurrentCoop = !useCurrentCoop;
                                                        if (useCurrentCoop) {
                                                            selectedCoopId = null;
                                                            showValidationError = false;
                                                        }
                                                    });
                                            },
                                            child: AnimatedContainer(
                                                duration: const Duration(milliseconds: 200),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color: useCurrentCoop
                                                        ? AppColors.success.withValues(alpha: 0.10)
                                                        : AppColors.surfaceVariant(context),
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(
                                                        color: showValidationError && !useCurrentCoop
                                                            ? AppColors.error
                                                            : useCurrentCoop
                                                                ? AppColors.success.withValues(alpha: 0.45)
                                                                : AppColors.border(context),
                                                        width: 1,
                                                    ),
                                                ),
                                                child: Row(
                                                    children: [
                                                        Icon(
                                                            useCurrentCoop
                                                                ? Icons.check_box_rounded
                                                                : Icons.check_box_outline_blank_rounded,
                                                            color: useCurrentCoop
                                                                ? AppColors.success
                                                                : AppColors.textTertiary(context),
                                                            size: 20,
                                                        ),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                            child: Text(
                                                                'Re-use the current coop for this transition',
                                                                style: TextStyle(
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: useCurrentCoop
                                                                        ? AppColors.success
                                                                        : AppColors.textSecondary(context),
                                                                ),
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),
                                        if (showValidationError)
                                        Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Row(
                                                children: [
                                                    const Icon(Icons.error_outline,
                                                        color: AppColors.error, size: 14),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                        child: Text(
                                                            'Please select a coop or check the box above.',
                                                            style: const TextStyle(
                                                                color: AppColors.error,
                                                                fontSize: 12,
                                                            ),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            actions: [
                                Row(
                                    children: [
                                        Expanded(
                                            child: OutlinedButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppColors.error,
                                                    side: const BorderSide(color: AppColors.error),
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10)),
                                                ),
                                                child: const Text('Cancel',
                                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                            ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            flex: 2,
                                            child: ElevatedButton.icon(
                                                onPressed: () async {
                                                    if (selectedCoopId == null && !useCurrentCoop) {
                                                        setState(() {
                                                                showValidationError = true;
                                                            });
                                                        return;
                                                    }

                                                    final response = await service.performPhaseTransition(
                                                        userId: userId,
                                                        currentCoopId: coopId,
                                                        farmId: farmId,
                                                        newCoopId: selectedCoopId ?? coopId,
                                                        newGrowingPhase: GrowingPhase.fromValue(newPhase),
                                                    );

                                                    response.success
                                                        ? _showSuccessSnackBar(
                                                            "Phase transition completed successfully",
                                                            onCoopUpdated,
                                                            context)
                                                        : _showErrorSnackBar(response.message, context);

                                                    Navigator.of(context).pop();
                                                    onCoopUpdated();
                                                },
                                                icon: const Icon(Icons.sync_rounded, size: 18),
                                                label: const Text('Confirm',
                                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppColors.warning,
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(10)),
                                                    elevation: 0,
                                                ),
                                            ),
                                        ),
                                    ],
                                ),
                            ],
                        );
                    },
                );
            },
        );
    }

    Widget _buildNotificationIcon(BuildContext context,
        {required IconData icon,
            required int count,
            required Color color,
            required bool hasPhaseTransition}) {
        if (hasPhaseTransition) {
            count++;
        }
        return Stack(
            clipBehavior: Clip.none,
            children: [
                Icon(icon, size: 18, color: color),
                if (count > 0)
                Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surfaceLight, width: 1.5),
                        ),
                        child: Text(
                            '$count',
                            style: const TextStyle(
                                fontSize: 6,
                                color: AppColors.surfaceLight,
                                fontWeight: FontWeight.bold,
                            ),
                        ),
                    ),
                ),
            ],
        );
    }

    String? _getTaskName(Map<String, dynamic> task) {
        final details = task['details'];
        if (details == null) return null;

        switch (task['type']) {
            case 'Medicine':
                return details['medicineName'];
            case 'Vaccine':
                return details['vaccineName'];
            case 'Feed':
                return details['feedType'];
            default:
            return null;
        }
    }

    void _showDetailsPopup(
        BuildContext context, String type, Map<String, dynamic> details) {
        // ── Helpers ───────────────────────────────────────────────────────────
        String formatKey(String key) {
            return key
                .replaceAllMapped(RegExp(r'[a-z][A-Z]'),
                    (match) => '${match.group(0)![0]} ${match.group(0)![1]}')
                .capitalize();
        }

        // Returns an icon that semantically matches a field key name
        IconData _fieldIcon(String key) {
            final k = key.toLowerCase();
            if (k.contains('date') || k.contains('day') || k.contains('age') )         return Icons.calendar_today_rounded;
            if (k.contains('name'))         return Icons.label_rounded;
            if (k.contains('dose') ||
                k.contains('dosage'))       return Icons.science_rounded;
            if (k.contains('quantity') ||
                k.contains('amount'))       return Icons.pin_rounded;
            if (k.contains('type') ||
                k.contains('feed'))         return Icons.grass_rounded;
            if (k.contains('note') ||
                k.contains('comment'))      return Icons.sticky_note_2_rounded;
            if (k.contains('status'))       return Icons.flag_rounded;
            if (k.contains('freq') ||
                k.contains('interval'))     return Icons.repeat_rounded;
            return Icons.info_outline_rounded;
        }

        // Header icon / colour per task type
        IconData typeIcon;
        Color typeColor;
        switch (type) {
            case 'Medicine':
                typeIcon = Icons.medication_rounded;
                typeColor = AppColors.error;
                break;
            case 'Vaccine':
                typeIcon = Icons.vaccines_rounded;
                typeColor = AppColors.info;
                break;
            case 'Feed':
                typeIcon = Icons.grass_rounded;
                typeColor = AppColors.success;
                break;
            default:
                typeIcon = Icons.task_alt_rounded;
                typeColor = AppColors.warning;
        }

        final visibleEntries = details.entries
            .where((e) => e.key != 'id')
            .toList();

        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            backgroundColor: Colors.transparent,
            builder: (context) {
                return ConstrainedBox(
                    // Never taller than 75 % of screen – prevents overflow
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.75,
                    ),
                    child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.surface(context),
                            borderRadius:
                                const BorderRadius.vertical(top: Radius.circular(24)),
                        ),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                // ── Handle ──────────────────────────────────
                                Center(
                                    child: Container(
                                        margin: const EdgeInsets.only(top: 12, bottom: 4),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                            color: AppColors.border(context),
                                            borderRadius: BorderRadius.circular(2),
                                        ),
                                    ),
                                ),
                                // ── Header ──────────────────────────────────
                                Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                                    child: Row(
                                        children: [
                                            Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                    color: typeColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Icon(typeIcon, color: typeColor, size: 22),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                        Text(
                                                            '$type Details',
                                                            style: TextStyle(
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppColors.textPrimary(context),
                                                            ),
                                                        ),
                                                        Text(
                                                            '${visibleEntries.length} field${visibleEntries.length == 1 ? '' : 's'}',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppColors.textTertiary(context),
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ],
                                    ),
                                ),
                                const SizedBox(height: 14),
                                Divider(height: 1, color: AppColors.divider(context)),

                                // ── Scrollable field list ────────────────────
                                Flexible(
                                    child: ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 8),
                                        shrinkWrap: true,
                                        itemCount: visibleEntries.length,
                                        separatorBuilder: (_, __) => Divider(
                                            height: 1,
                                            color: AppColors.divider(context),
                                        ),
                                        itemBuilder: (context, index) {
                                            final entry = visibleEntries[index];
                                            final icon = _fieldIcon(entry.key);
                                            return Padding(
                                                padding: const EdgeInsets.symmetric(
                                                    vertical: 10),
                                                child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.center,
                                                    children: [
                                                        // Field icon badge
                                                        Container(
                                                            padding: const EdgeInsets.all(7),
                                                            decoration: BoxDecoration(
                                                                color: typeColor.withValues(
                                                                    alpha: 0.10),
                                                                borderRadius:
                                                                    BorderRadius.circular(9),
                                                            ),
                                                            child: Icon(icon,
                                                                size: 15,
                                                                color: typeColor),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        // Label + value stacked
                                                        Expanded(
                                                            child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment.start,
                                                                children: [
                                                                    Text(
                                                                        formatKey(entry.key),
                                                                        style: TextStyle(
                                                                            fontSize: 11,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                            color: AppColors
                                                                                .textTertiary(
                                                                                    context),
                                                                            letterSpacing: 0.3,
                                                                        ),
                                                                    ),
                                                                    const SizedBox(height: 2),
                                                                    Text(
                                                                        '${entry.value}',
                                                                        style: TextStyle(
                                                                            fontSize: 14,
                                                                            fontWeight:
                                                                                FontWeight.w600,
                                                                            color: AppColors
                                                                                .textPrimary(
                                                                                    context),
                                                                        ),
                                                                    ),
                                                                ],
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            );
                                        },
                                    ),
                                ),

                                Divider(height: 1, color: AppColors.divider(context)),

                                // ── Close button ─────────────────────────────
                                SafeArea(
                                    top: false,
                                    child: Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
                                        child: SizedBox(
                                            width: double.infinity,
                                            height: 48,
                                            child: ElevatedButton(
                                                onPressed: () => Navigator.of(context).pop(),
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        AppColors.adaptivePrimary(context),
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(12)),
                                                ),
                                                child: const Text('Close',
                                                    style: TextStyle(
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 15)),
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
}

void _showPhaseTransitionInfoPopup(BuildContext context) {
    final pageController = PageController();
    int currentPage = 0;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) {
                return Container(
                    decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                        20, 0, 20,
                        MediaQuery.of(context).viewInsets.bottom +
                            MediaQuery.of(context).viewPadding.bottom +
                            24),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            // Handle
                            Center(
                                child: Container(
                                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: AppColors.border(context),
                                        borderRadius: BorderRadius.circular(2),
                                    ),
                                ),
                            ),
                            // Header
                            Row(
                                children: [
                                    Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: AppColors.info.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.info_outline_rounded,
                                            color: AppColors.info, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                        'Phase Transition Guide',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary(context),
                                        ),
                                    ),
                                ],
                            ),
                            const SizedBox(height: 16),
                            // PageView
                            SizedBox(
                                height: 230,
                                child: PageView(
                                    controller: pageController,
                                    onPageChanged: (page) =>
                                        setState(() => currentPage = page),
                                    children: [
                                        _buildInfoPage(
                                            context,
                                            icon: Icons.sync_rounded,
                                            color: AppColors.warning,
                                            title: 'What is Phase Transition?',
                                            body: 'Phase transition moves chickens between growth stages — Brooding → Growing → Production/Finishing. It requires careful planning to maintain flock health and performance through each stage.',
                                        ),
                                        _buildInfoPage(
                                            context,
                                            icon: Icons.layers_rounded,
                                            color: AppColors.info,
                                            title: 'Growth Phase Overview',
                                            bulletPoints: [
                                                '🐣  Brooding Phase — warmth, hydration, and early vaccinations.',
                                                '🐔  Growing / Rearing — feed, spacing, and health monitoring.',
                                                '🥚  Production / Finishing — prepare for egg production or market.',
                                            ],
                                        ),
                                        _buildInfoPage(
                                            context,
                                            icon: Icons.checklist_rounded,
                                            color: AppColors.success,
                                            title: 'How to Transition',
                                            bulletPoints: [
                                                '1.  Evaluate readiness — check age, weight, and health.',
                                                '2.  Prepare environment — clean & sanitise the coop.',
                                                '3.  Move gradually — transition in cooler parts of the day.',
                                                '4.  Update records — log all transition details in the app.',
                                            ],
                                        ),
                                    ],
                                ),
                            ),
                            const SizedBox(height: 12),
                            // Animated pill-dot indicators
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (i) {
                                    final isActive = i == currentPage;
                                    return AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeInOut,
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        height: 8,
                                        width: isActive ? 24 : 8,
                                        decoration: BoxDecoration(
                                            color: isActive
                                                ? AppColors.adaptivePrimary(context)
                                                : AppColors.border(context),
                                            borderRadius: BorderRadius.circular(4),
                                        ),
                                    );
                                }),
                            ),
                            const SizedBox(height: 6),
                            Text(
                                'Swipe to read more',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textTertiary(context),
                                ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.adaptivePrimary(context),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('Got it',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: 15)),
                                ),
                            ),
                        ],
                    ),
                );
            },
        ),
    );
}

Widget _buildInfoPage(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    String? body,
    List<String>? bulletPoints,
}) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Row(
                        children: [
                            Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(
                                    title,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                    ),
                                ),
                            ),
                        ],
                    ),
                    const SizedBox(height: 12),
                    if (body != null)
                    Text(
                        body,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(context),
                            height: 1.5,
                        ),
                    ),
                    if (bulletPoints != null)
                    ...bulletPoints.map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                            point,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary(context),
                                height: 1.4,
                            ),
                        ),
                    )),
                ],
            ),
        ),
    );
}

void _showErrorSnackBar(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
        Common.buildSnackBar(message, AppColors.error),
    );
}

void _showSuccessSnackBar(
    String message, VoidCallback onCoopUpdated, BuildContext context) {
    onCoopUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
        Common.buildSnackBar(message, AppColors.success),
    );
}

extension StringExtension on String {
    String capitalize() {
        return split(' ').map((str) {
                return str[0].toUpperCase() + str.substring(1);
            }).join(' ');
    }
}
