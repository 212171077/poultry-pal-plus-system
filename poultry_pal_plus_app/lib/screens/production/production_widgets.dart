import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';

import '../../service/production_service.dart';
import '../common.dart';

final DateFormat _dateFormat = DateFormat('d MMM yyyy');

String formatDate(DateTime? date) => date == null ? '—' : _dateFormat.format(date);

String errorMessage(Object error) => error is ProductionApiException
    ? error.message
    : error is String ? error : 'Something went wrong';

void showError(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
        Common.buildSnackBar(errorMessage(error), AppColors.error));

void showSuccess(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(
        Common.buildSnackBar(message, AppColors.success));

/// Runs [action], reports failures and returns true on success.
Future<bool> runAction(
    BuildContext context, Future<void> Function() action, {String? success}) async {
    try {
        await action();
        if (context.mounted && success != null) showSuccess(context, success);
        return true;
    } catch (e) {
        if (context.mounted) showError(context, e);
        return false;
    }
}

Future<void> showInfoDialog(BuildContext context, String title, String body) =>
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
            ],
        ),
    );

Future<bool> confirm(BuildContext context, String title, String message,
    {String action = 'Confirm'}) async {
    final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
            ],
        ),
    );
    return result ?? false;
}

/// Scrollable form sheet that clears the keyboard and system navigation.
Future<T?> showFormSheet<T>(BuildContext context,
    {required String title, String? info, required Widget Function(BuildContext) builder}) {
    return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        backgroundColor: AppColors.surface(context),
        builder: (ctx) => Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SafeArea(
            top: false,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                                Row(children: [
                                    Expanded(
                                        child: Text(title,
                                            style: Theme.of(ctx).textTheme.titleLarge
                                                ?.copyWith(fontWeight: FontWeight.bold)),
                                    ),
                                    if (info != null)
                                        IconButton(
                                            icon: const Icon(Icons.info_outline),
                                            tooltip: 'About this form',
                                            onPressed: () => showInfoDialog(ctx, title, info),
                                        ),
                                ]),
                                const SizedBox(height: 12),
                                builder(ctx),
                    ]),
            ),
            ),
        ),
    );
}

InputDecoration _decoration(String label, String? helper, {Widget? suffix}) =>
    InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );

/// Number text field with a descriptive helper line.
class NumberField extends StatelessWidget {
    final String label;
    final String? helper;
    final TextEditingController controller;
    final bool decimal;
    final ValueChanged<String>? onChanged;

    const NumberField({
        super.key,
        required this.label,
        required this.controller,
        this.helper,
        this.decimal = false,
        this.onChanged,
    });

    @override
    Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            style: Theme.of(context).textTheme.bodyMedium,
            controller: controller,
            onChanged: onChanged,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            decoration: _decoration(label, helper),
        ),
    );
}

class AppTextInput extends StatelessWidget {
    final String label;
    final String? helper;
    final TextEditingController controller;

    const AppTextInput(
        {super.key, required this.label, required this.controller, this.helper});

    @override
    Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            style: Theme.of(context).textTheme.bodyMedium,
            controller: controller, decoration: _decoration(label, helper)),
    );
}

class DatePickerField extends StatelessWidget {
    final String label;
    final DateTime value;
    final ValueChanged<DateTime> onChanged;
    final String? helper;

    const DatePickerField({
        super.key,
        required this.label,
        required this.value,
        required this.onChanged,
        this.helper,
    });

    @override
    Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
                final picked = await showDatePicker(
                    context: context,
                    initialDate: value,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                );
                if (picked != null) onChanged(picked);
            },
            child: InputDecorator(
                decoration: _decoration(label, helper,
                    suffix: const Icon(Icons.calendar_today_outlined, size: 20)),
                child: Text(formatDate(value),
                    style: Theme.of(context).textTheme.bodyMedium),
            ),
        ),
    );
}

class DropdownInput<T> extends StatelessWidget {
    final String label;
    final T? value;
    final List<DropdownMenuItem<T>> items;
    final ValueChanged<T?> onChanged;
    final String? helper;

    const DropdownInput({
        super.key,
        required this.label,
        required this.value,
        required this.items,
        required this.onChanged,
        this.helper,
    });

    @override
    Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<T>(
            style: Theme.of(context).textTheme.bodyMedium,
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            decoration: _decoration(label, helper),
        ),
    );
}

class SubmitButton extends StatelessWidget {
    final String label;
    final bool busy;
    final VoidCallback? onPressed;

    const SubmitButton(
        {super.key, required this.label, required this.busy, required this.onPressed});

    @override
    Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
            onPressed: busy ? null : onPressed,
            child: busy
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(label),
        ),
    );
}

class StatusChip extends StatelessWidget {
    final String label;
    final Color color;

    const StatusChip(this.label, this.color, {super.key});

    @override
    Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
}

/// Rounded card matching the dashboard cards.
class SectionCard extends StatelessWidget {
    final Widget child;
    final EdgeInsetsGeometry padding;

    const SectionCard(
        {super.key, required this.child, this.padding = const EdgeInsets.all(14)});

    @override
    Widget build(BuildContext context) => Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shadowColor: Colors.black.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: AppColors.surface(context),
        child: Padding(padding: padding, child: child),
    );
}

class SectionTitle extends StatelessWidget {
    final String title;
    final String? info;
    final Widget? trailing;

    const SectionTitle(this.title, {super.key, this.info, this.trailing});

    @override
    Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 2),
        child: Row(children: [
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            if (info != null)
                IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.info_outline,
                        size: 20, color: AppColors.textSecondary(context)),
                    tooltip: 'What is this?',
                    onPressed: () => showInfoDialog(context, title, info!),
                ),
            if (trailing != null) trailing!,
        ]),
    );
}

class EmptyState extends StatelessWidget {
    final IconData icon;
    final String message;

    const EmptyState({super.key, required this.icon, required this.message});

    @override
    Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(children: [
            Icon(icon, size: 48, color: AppColors.textTertiary(context)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textTertiary(context),
                    fontWeight: FontWeight.w500)),
        ]),
    );
}

/// Small labelled value used inside cards.
class KeyValue extends StatelessWidget {
    final String label;
    final String value;

    const KeyValue(this.label, this.value, {super.key});

    @override
    Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(label,
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
    );
}
