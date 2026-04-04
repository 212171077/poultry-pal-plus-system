import 'package:flutter/material.dart';
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
                                color: Colors.grey,
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
                        ? [Colors.brown[50]!, Colors.brown[200]!]
                        : [Colors.white, Colors.white],
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
                                                    color: Colors.red[300]!,
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
                                                    color: Colors.blue[300]!,
                                                    hasPhaseTransition: hasPhaseTransition,
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
                                                        color: Theme.of(context).primaryColor,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                    "${widget.coop.coopType.toLowerCase().capitalize()} (${widget.coop.growthPhase.value})",
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Theme.of(context).primaryColorDark,
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
                                            color: Colors.green,
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
                                color: Colors.white,
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
                                                            backgroundColor: success ? Colors.green : Colors.red,
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
                                                            backgroundColor: Colors.red,
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
                                                                backgroundColor: Colors.white, // White background
                                                                foregroundColor: Theme.of(context).primaryColor, // Icon & text color
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
                                                                                    color: Theme.of(context).primaryColor,
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
                                                                            color: Theme.of(context).primaryColor,
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
                                    Card(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12.0),
                                        ),
                                        elevation: 3,
                                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Padding(
                                            padding: const EdgeInsets.fromLTRB(16, 3, 16, 3),
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Row(
                                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                        children: [
                                                            Text(
                                                                "Perform Phase Transition",
                                                                style: TextStyle(
                                                                    fontSize: 14,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Theme.of(context).primaryColor),
                                                            ),
                                                            IconButton(
                                                                icon: const Icon(Icons.info_outline,
                                                                    color: Colors.blue),
                                                                onPressed: () =>
                                                                _showPhaseTransitionInfoPopup(context),
                                                            ),
                                                        ],
                                                    ),
                                                    const Text(
                                                        'Your chickens are ready to transition to the next phase. '
                                                        'Tap "Confirm" to proceed or the info icon for more details.',
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.green,
                                                            fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Column(
                                                        children: [
                                                            Row(
                                                                children: [
                                                                    Column(
                                                                        children: [
                                                                            const Icon(Icons.circle,
                                                                                color: Colors.green, size: 16),
                                                                            const SizedBox(height: 4),
                                                                            Text(
                                                                                widget.coop.phaseTransition
                                                                                    .currentPhase.value,
                                                                                style: TextStyle(
                                                                                    fontSize: 11,
                                                                                    color: Colors.green[800],
                                                                                    fontWeight: FontWeight.bold,
                                                                                ),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                    const Expanded(
                                                                        child: Divider(
                                                                            color: Colors.green,
                                                                            thickness: 2,
                                                                            indent: 0,
                                                                            endIndent: 0,
                                                                        ),
                                                                    ),
                                                                    const Column(
                                                                        children: [
                                                                            Icon(Icons.arrow_forward_ios,
                                                                                color: Colors.green, size: 18),
                                                                            SizedBox(height: 4),
                                                                        ],
                                                                    ),
                                                                    const Expanded(
                                                                        child: Divider(
                                                                            color: Colors.green,
                                                                            thickness: 2,
                                                                            indent: 0,
                                                                            endIndent: 0,
                                                                        ),
                                                                    ),
                                                                    Column(
                                                                        children: [
                                                                            const Icon(Icons.circle_outlined,
                                                                                color: Colors.grey, size: 16),
                                                                            const SizedBox(height: 4),
                                                                            Text(
                                                                                widget.coop.phaseTransition.newPhase
                                                                                    .value,
                                                                                style: TextStyle(
                                                                                    fontSize: 11,
                                                                                    color: Colors.grey[700],
                                                                                    fontWeight: FontWeight.bold,
                                                                                ),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                ],
                                                            ),
                                                            ElevatedButton.icon(
                                                                onPressed: () =>
                                                                _showConfirmPhaseTransitionDialog(
                                                                    context,
                                                                    widget.coop.phaseTransition.currentPhase
                                                                        .value,
                                                                    widget.coop.phaseTransition.newPhase
                                                                        .value,
                                                                    widget.user.id,
                                                                    widget.farm.id,
                                                                    widget.coop.id,
                                                                    widget.coop.phaseTransition.transitionCoops,
                                                                    () => widget.onCoopUpdated(),
                                                                ),
                                                                icon: const Icon(Icons.sync, size: 18),
                                                                // Icon for added visual interest
                                                                label: const Text(
                                                                    'Confirm',
                                                                    style: TextStyle(
                                                                        fontSize: 14,
                                                                        fontWeight: FontWeight.bold),
                                                                ),
                                                                style: ElevatedButton.styleFrom(
                                                                    padding: const EdgeInsets.symmetric(
                                                                        vertical: 10, horizontal: 16),
                                                                    shape: RoundedRectangleBorder(
                                                                        borderRadius: BorderRadius.circular(8),
                                                                    ),
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ],
                                            ),
                                        ),
                                    ),
                                    if (overdueTasks.isNotEmpty) ...[
                                        _buildSectionTitle(
                                            context, 'Overdue Tasks', Colors.red[800]!),
                                        _buildTaskList(
                                            context,
                                            overdueTasks,
                                            widget.coop,
                                            widget.farm,
                                            widget.user,
                                            Colors.red[50]!,
                                            Colors.red[800]!,
                                            onCoopUpdated),
                                    ],
                                    if (upcomingReminders.isNotEmpty) ...[
                                        SizedBox(height: overdueTasks.isNotEmpty ? 20 : 0),
                                        _buildSectionTitle(
                                            context, 'Upcoming Reminders', Colors.blue[800]!),
                                        _buildTaskList(
                                            context,
                                            upcomingReminders,
                                            widget.coop,
                                            widget.farm,
                                            widget.user,
                                            Colors.blue[50]!,
                                            Colors.blue[800]!,
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
                                                            color: Colors.grey,
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

    Widget _buildSectionTitle(BuildContext context, String title, Color color) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
                title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                ),
            ),
        );
    }

    Widget _buildTaskList(
        BuildContext context,
        List<Map<String, dynamic>> tasks,
        Coop coop,
        Farm farm,
        User user,
        Color backgroundColor,
        Color iconColor,
        VoidCallback onCoopUpdated) {
        return Column(
            children: tasks.map((task) {
                    final details = task['details'];
                    final taskName = _getTaskName(task);

                    return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
                        color: backgroundColor,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                                                        color: Colors.grey[600],
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
                                        icon: const Icon(Icons.settings, color: Colors.green),
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
                                                        Icon(Icons.check_circle, color: Colors.green),
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
                                                        Icon(Icons.cancel, color: Colors.amber),
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
                                                        Icon(Icons.delete, color: Colors.red),
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
                                        fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                Text(
                                    action,
                                    style: TextStyle(color: Colors.grey[700]),
                                    overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                    'Reminder: ',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                Text(
                                    task['type'] + ": " + _getTaskName(task) ?? 'Unknown',
                                    style: TextStyle(color: Colors.grey[700]),
                                    overflow: TextOverflow.visible,
                                ),

                                const SizedBox(height: 15),
                                // Action Comment
                                const Text(
                                    'Add Comment (Optional):',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600, color: Colors.black87),
                                ),
                                const SizedBox(height: 5),
                                TextField(
                                    controller: actionCommentController,
                                    maxLines: 2,
                                    decoration: InputDecoration(
                                        hintText: 'Add your comment...',
                                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                                        border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                        ),
                                        fillColor: Colors.grey[100],
                                        filled: true,
                                    ),
                                ),
                            ],
                        ),
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
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
                                backgroundColor: Theme.of(context).primaryColor,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text(
                                'Submit',
                                style: TextStyle(color: Colors.white),
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
        final TextEditingController actionCommentController = TextEditingController();
        PoultryPalService service = PoultryPalService();
        String? selectedCoopId; // To store the selected coop ID
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
                            title: const Row(
                                children: [
                                    Text(
                                        'Confirm Phase Transition',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                    ),
                                ],
                            ),
                            content: SingleChildScrollView(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Common.buildReadout('Current Growing Phase', currentPhase),
                                        const SizedBox(height: 10),
                                        Common.buildReadout('New Growing Phase', newPhase),
                                        const SizedBox(height: 10),
                                        if (list.isNotEmpty)
                                        Text(
                                            'Select Coop for Transition:',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blueGrey[700],
                                                fontSize: 12,
                                            ),
                                        ),
                                        list.isNotEmpty
                                            ? Container(
                                                decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: showValidationError &&
                                                            selectedCoopId == null &&
                                                            !useCurrentCoop
                                                            ? Colors.red
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
                                                                    useCurrentCoop = false; // Clear the checkbox
                                                                    showValidationError = false;
                                                                }
                                                            });
                                                    },
                                                    hintText: 'Select a coop',
                                                ),
                                            )
                                            : Common.buildReadout2(
                                                'No suitable coop is available for the phase transition. '
                                                'You can add a new coop on the home page and return here to complete the transition. '
                                                'Alternatively, re-use the current coop for this transition.',
                                                Colors.blue.shade700,
                                            ),
                                        const SizedBox(height: 10),
                                        Container(
                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black.withOpacity(0.5),
                                                        blurRadius: 2,
                                                        offset: const Offset(0, 1),
                                                    ),
                                                ],
                                                border: Border.all(
                                                    color: showValidationError && !useCurrentCoop
                                                        ? Colors.red
                                                        : Colors.transparent,
                                                ),
                                            ),
                                            child: Row(
                                                children: [
                                                    Checkbox(
                                                        value: useCurrentCoop,
                                                        onChanged: (value) {
                                                            setState(() {
                                                                    useCurrentCoop = value ?? false;
                                                                    if (useCurrentCoop) {
                                                                        selectedCoopId = null; // Clear dropdown value
                                                                        showValidationError = false;
                                                                    }
                                                                });
                                                        },
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                        child: Text(
                                                            'Re-use the current coop for this transition.',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: useCurrentCoop
                                                                    ? Colors.green.shade700
                                                                    : Colors.blueGrey[700],
                                                                fontWeight: FontWeight.bold,
                                                            ),
                                                            overflow: TextOverflow.clip,
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        if (showValidationError)
                                        const Padding(
                                            padding: EdgeInsets.only(top: 8.0),
                                            child: Text(
                                                'Please select a coop from the dropdown or check the box to re-use the current coop.',
                                                style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 12,
                                                ),
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                            actions: [
                                TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child:
                                    const Text('Cancel', style: TextStyle(color: Colors.red)),
                                ),
                                ElevatedButton(
                                    onPressed: () async {
                                        if (selectedCoopId == null && !useCurrentCoop) {
                                            setState(() {
                                                    showValidationError = true; // Highlight errors
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
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Theme.of(context).primaryColor,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                        ),
                                    ),
                                    child: const Text(
                                        'Submit',
                                        style: TextStyle(color: Colors.white),
                                    ),
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
                            color: Colors.red[600],
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                            '$count',
                            style: const TextStyle(
                                fontSize: 6,
                                color: Colors.white,
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
        String formatKey(String key) {
            // Split camel case or lowercase words and capitalize each word
            return key
                .replaceAllMapped(RegExp(r'[a-z][A-Z]'),
                    (match) => '${match.group(0)![0]} ${match.group(0)![1]}')
                .capitalize();
        }

        showDialog(
            context: context,
            builder: (context) {
                return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                    ),
                    title: Text(
                        '$type Details',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                        ),
                    ),
                    content: SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: details.entries.map((entry) {
                                    if (entry.key != "id") {
                                        return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                                            child: RichText(
                                                text: TextSpan(
                                                    text: '${formatKey(entry.key)}: ',
                                                    style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black,
                                                        fontSize: 16,
                                                    ),
                                                    children: [
                                                        TextSpan(
                                                            text: '${entry.value}',
                                                            style: TextStyle(
                                                                fontWeight: FontWeight.normal,
                                                                color: Colors.grey[700],
                                                                fontSize: 16,
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        );
                                    } else {
                                        return const SizedBox(height: 0);
                                    }
                                }).toList(),
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
}

void _showPhaseTransitionInfoPopup(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            title: Text(
                'Phase Transition Information',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                ),
            ),
            content: SizedBox(
                height: 300, // Set a fixed height for the scrollable area
                width: double.maxFinite,
                child: Column(
                    children: [
                        // PageView with categories
                        Expanded(
                            child: PageView(
                                children: [
                                    Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    'Phase Transition Overview',
                                                    style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.orange,
                                                    ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                    'Phase transition is the process of moving chickens between growth stages, such as from brooding to growing or from growing to production. It involves careful planning to ensure the chickens\' health and comfort, including evaluating their readiness, adjusting their environment, and monitoring their health to minimize stress and ensure a smooth transition.',
                                                ),
                                            ],
                                        ),
                                    ),
                                    // Phase Information
                                    Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    'Phase Information',
                                                    style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blueAccent,
                                                    ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                    '• Brooding Phase: Focus on warmth, hydration, and vaccination.'),
                                                Text(
                                                    '• Growing Phase: Prioritize feed, spacing, and health.'),
                                                Text(
                                                    '• Production Phase: Prepare for production or market.'),
                                            ],
                                        ),
                                    ),
                                    // How to Transition Chickens
                                    Container(
                                        padding: const EdgeInsets.all(8.0),
                                        decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    'How to Transition Chickens',
                                                    style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.green,
                                                    ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                    '1. Evaluate Readiness: Check age, size, and health of chickens.'),
                                                Text(
                                                    '2. Prepare Environment: Clean and sanitize the new coop.'),
                                                Text(
                                                    '3. Gradual Transition: Move chickens during cooler parts of the day.'),
                                                Text(
                                                    '4. Update Records: Log transition details in the app.'),
                                            ],
                                        ),
                                    ),
                                    // Phase Transition Overview
                                ],
                            ),
                        ),
                        // Swipe indicator (dots)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                                3, // Number of pages
                                (index) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    height: 8,
                                    width: 8,
                                    decoration: BoxDecoration(
                                        color: Colors.blueAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.blueAccent,
                                            width: 2,
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ],
                ),
            ),
            actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                        'Close',
                        style: TextStyle(
                            color: Colors.blueAccent, fontWeight: FontWeight.bold),
                    ),
                ),
            ],
        ),
    );
}

void _showErrorSnackBar(String message, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
        Common.buildSnackBar(message, Colors.red),
    );
}

void _showSuccessSnackBar(
    String message, VoidCallback onCoopUpdated, BuildContext context) {
    onCoopUpdated();
    ScaffoldMessenger.of(context).showSnackBar(
        Common.buildSnackBar(message, Colors.green),
    );
}

extension StringExtension on String {
    String capitalize() {
        return split(' ').map((str) {
                return str[0].toUpperCase() + str.substring(1);
            }).join(' ');
    }
}
