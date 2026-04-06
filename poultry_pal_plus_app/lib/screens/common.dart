import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:lottie/lottie.dart';
import 'package:poultry_pal_plus_app/models/box_size.dart';
import '../models/egg_size.dart';
import '../models/growing_phase.dart';

class Common {
    static SnackBar buildSnackBar(String message, Color backgroundColor) {
        return SnackBar(
            content: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                    const Icon(Icons.check_circle, color: AppColors.surfaceLight),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            message,
                            style: const TextStyle(color: AppColors.surfaceLight),
                            textAlign: TextAlign.start,
                        ),
                    ),
                ],
            ),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
            ),
        );
    }

    // ── Text Field with real-time inline validation ───────────────────────────
    static Widget buildTextField({
        required String label,
        required IconData icon,
        required void Function(String) onChanged,
        String? Function(String?)? validator,
        TextInputType? keyboardType,
        required BuildContext context,
        String? initialValue,
        bool isPassword = false,
    }) {
        return _AppTextField(
            label: label,
            icon: icon,
            onChanged: onChanged,
            validator: validator,
            keyboardType: keyboardType,
            initialValue: initialValue,
            isPassword: isPassword,
        );
    }

    // ── Currency field with thousand-separator formatting ──────────────────────
    static Widget buildCurrencyField({
        required String label,
        required void Function(double) onChanged,
        String? Function(String?)? validator,
        double initialValue = 0,
        String currencySymbol = 'R',
        required BuildContext context,
    }) {
        return _AppCurrencyField(
            label: label,
            onChanged: onChanged,
            validator: validator,
            initialValue: initialValue,
            currencySymbol: currencySymbol,
        );
    }

    // ── Stepper field with +/- buttons ────────────────────────────────────────
    static Widget buildStepperField({
        required String label,
        required int value,
        required void Function(int) onChanged,
        int min = 0,
        int max = 99999,
        bool showError = false,
        String? errorText,
        String? Function(int?)? validator,
        required BuildContext context,
    }) {
        if (validator == null) {
            return _StepperField(
                label: label,
                initialValue: value,
                onChanged: onChanged,
                min: min,
                max: max,
                showError: showError,
                errorText: errorText,
            );
        }
        // Wrap in FormField so it integrates with Form.validate()
        return FormField<int>(
            initialValue: value,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            builder: (field) {
                return _StepperField(
                    label: label,
                    initialValue: value,
                    onChanged: (val) {
                        field.didChange(val);
                        onChanged(val);
                    },
                    min: min,
                    max: max,
                    showError: showError || field.hasError,
                    errorText: field.hasError ? field.errorText : errorText,
                );
            },
        );
    }

    // ...existing code (buildCoopTypeDropdownField, buildExpenseTypeDropdownField unchanged)...

    static Widget buildCoopTypeDropdownField({
        required String value,
        required void Function(String?) onChanged,
        String? Function(String?)? validator,
        required BuildContext context,
    }) {
        final primary = AppColors.adaptivePrimary(context);
        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary.withAlpha(128)),
        );

        return DropdownButtonFormField<String>(
            decoration: InputDecoration(
                labelText: 'Coop Type',
                labelStyle: TextStyle(fontSize: 14, color: primary),
                prefixIcon: Icon(Icons.category_outlined, color: AppColors.iconPrimary(context)),
                filled: true,
                fillColor: AppColors.surfaceVariant(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                    borderSide: BorderSide(color: primary, width: 2),
                ),
                errorBorder: border.copyWith(
                    borderSide: BorderSide(color: AppColors.adaptiveError(context)),
                ),
                focusedErrorBorder: border.copyWith(
                    borderSide: BorderSide(color: AppColors.adaptiveError(context), width: 2),
                ),
            ),
            value: value,
            onChanged: onChanged,
            validator: validator,
            menuMaxHeight: 250,
            isExpanded: true,
            dropdownColor: AppColors.surface(context),
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.iconPrimary(context)),
            items: ['Select coop type', 'Broiler', 'Layers'].map((type) {
                    return DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                            type,
                            style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 14,
                            ),
                        ),
                    );
                }).toList(),
        );
    }

    static Widget buildExpenseTypeDropdownField({
        required String value,
        required void Function(String?) onChanged,
        String? Function(String?)? validator,
        required BuildContext context,
    }) {
        final primary = AppColors.adaptivePrimary(context);
        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary.withAlpha(128)),
        );

        final mortalityReasons = {
            'Select expense type': '',
            'Feed Costs': 'Includes expenses for purchasing feed for chickens, which is often the largest ongoing cost in poultry farming.',
            'Chicks or Hatching Eggs': 'The initial cost of purchasing day-old chicks or hatching eggs.',
            'Housing and Coop Maintenance': 'Covers expenses for building, maintaining, and upgrading chicken coops and housing.',
            'Vaccination and Medications': 'Expenses for vaccines, antibiotics, and other medications to prevent diseases.',
            'Heating, Cooling, and Ventilation': 'The cost of maintaining optimal temperature and ventilation in coops.',
            'Water Supply and Equipment': 'Expenses for maintaining a constant water supply, including water dispensers.',
            'Labor Costs': 'Costs associated with hiring workers or laborers for feeding, cleaning, managing.',
            'Electricity and Utilities': 'Utility costs for powering equipment, lights, heating, cooling.',
            'Transportation and Delivery': 'Costs involved in transporting supplies or moving chickens to markets.',
            'Cleaning and Biosecurity Supplies': 'Expenses for cleaning products, disinfectants, and biosecurity measures.',
            'Insurance and Licensing': 'Costs for insuring the farm, livestock, and equipment.',
            'Bedding and Nesting Material': 'Recurring costs for bedding materials like straw, shavings, or sand.',
            'Breeding Costs': 'Costs related to breeding programs, such as incubators and brooding equipment.',
            'Marketing and Sales Expenses': 'Expenses for advertising, promotions, or packaging materials.',
            'Equipment and Tools': 'One-time or recurring costs for essential equipment like feeders, waterers.',
            'Waste Disposal': 'Costs related to disposing of poultry waste, dead birds, or unused materials.',
            'Record-Keeping and Software': 'Subscription fees or consulting costs for record-keeping and monitoring software.',
            'Miscellaneous Supplies': 'Other small expenses that don\'t fall into the above categories.',
        };

        return DropdownButtonFormField<String>(
            decoration: InputDecoration(
                labelText: 'Expense Type',
                labelStyle: TextStyle(fontSize: 14, color: primary),
                prefixIcon: Icon(Icons.receipt_long_outlined, color: AppColors.iconPrimary(context)),
                filled: true,
                fillColor: AppColors.surfaceVariant(context),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                    borderSide: BorderSide(color: primary, width: 2),
                ),
                errorBorder: border.copyWith(
                    borderSide: BorderSide(color: AppColors.adaptiveError(context)),
                ),
                focusedErrorBorder: border.copyWith(
                    borderSide: BorderSide(color: AppColors.adaptiveError(context), width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
            value: value,
            onChanged: onChanged,
            validator: validator,
            isExpanded: true,
            dropdownColor: AppColors.surface(context),
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.iconPrimary(context)),
            selectedItemBuilder: (context) {
                return mortalityReasons.keys.map((key) {
                        return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                                key,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: key == 'Select expense type'
                                        ? AppColors.textSecondary(context)
                                        : AppColors.textPrimary(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                            ),
                        );
                    }).toList();
            },
            items: mortalityReasons.entries.map((entry) {
                    return DropdownMenuItem(
                        value: entry.key,
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width - 120 - 50,
                            ),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                    if (entry.key == 'Select expense type')
                                    Row(children: [
                                            Icon(Icons.category_outlined, color: AppColors.adaptivePrimary(context)),
                                            const SizedBox(width: 10),
                                        ])
                                    else if (entry.value.isNotEmpty)
                                    Row(children: [
                                            GestureDetector(
                                                onTap: () {
                                                    showDialog(
                                                        context: context,
                                                        builder: (BuildContext context) {
                                                            return AlertDialog(
                                                                title: Text(entry.key),
                                                                content: Text(entry.value),
                                                                actions: [
                                                                    TextButton(
                                                                        onPressed: () => Navigator.of(context).pop(),
                                                                        child: const Text('Close'),
                                                                    ),
                                                                ],
                                                            );
                                                        },
                                                    );
                                                },
                                                child: const Icon(Icons.info_outline, color: AppColors.info),
                                            ),
                                            const SizedBox(width: 10),
                                        ]),
                                    Flexible(
                                        child: Text(
                                            entry.key,
                                            style: TextStyle(
                                                fontWeight: FontWeight.normal,
                                                fontSize: 14,
                                                color: AppColors.textPrimary(context),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    );
                }).toList(),
        );
    }

    static Widget buildDateField({
        required BuildContext context,
        required String label,
        required DateTime? date,
        required void Function(DateTime) onDateSelected,
        bool hasError = false,
        String? errorText,
    }) {
        final errorColor = AppColors.adaptiveError(context);
        final primary = AppColors.adaptivePrimary(context);

        final borderColor = hasError
            ? errorColor
            : primary.withAlpha(128);

        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
        );

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                InkWell(
                    onTap: () async {
                        final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: date ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2101),
                        );
                        if (pickedDate != null) {
                            onDateSelected(pickedDate);
                        }
                    },
                    child: InputDecorator(
                        decoration: InputDecoration(
                            labelText: label,
                            labelStyle: TextStyle(
                                color: hasError ? errorColor : primary,
                                fontSize: 14,
                            ),
                            prefixIcon: Icon(Icons.calendar_today, color: primary),
                            filled: true,
                            fillColor: AppColors.surfaceVariant(context),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                            border: border,
                            enabledBorder: border,
                            focusedBorder: border.copyWith(
                                borderSide: BorderSide(
                                    color: hasError ? errorColor : primary,
                                    width: 2,
                                ),
                            ),
                            errorBorder: border.copyWith(
                                borderSide: BorderSide(color: errorColor),
                            ),
                            focusedErrorBorder: border.copyWith(
                                borderSide: BorderSide(color: errorColor, width: 2),
                            ),
                        ),
                        child: Text(
                            date != null
                                ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                                : 'Select date',
                            style: TextStyle(
                                fontSize: 14,
                                color: date != null
                                    ? AppColors.textPrimary(context)
                                    : (hasError ? errorColor : AppColors.textSecondary(context)),
                            ),
                        ),
                    ),
                ),
                if (hasError && errorText != null)
                Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Text(errorText, style: TextStyle(color: errorColor, fontSize: 12)),
                ),
            ],
        );
    }

    static Widget buildDropdown({
        required String? selectedValue,
        required List<DropdownMenuItem<String>> items,
        required ValueChanged<String?> onChanged,
        required BuildContext context,
        String hintText = 'Select an option',
        String? label,
        IconData? prefixIcon,
        bool showError = false,
    }) {
        final primary = AppColors.adaptivePrimary(context);
        final errorColor = AppColors.adaptiveError(context);
        final defaultBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary.withAlpha(128)),
        );
        final errorBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: errorColor),
        );

        return DropdownButtonFormField<String>(
            value: selectedValue,
            decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(
                    fontSize: 14,
                    color: showError ? errorColor : primary,
                ),
                prefixIcon: prefixIcon != null
                    ? Icon(prefixIcon, color: AppColors.iconPrimary(context))
                    : null,
                filled: true,
                fillColor: AppColors.surfaceVariant(context),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: defaultBorder,
                enabledBorder: showError ? errorBorder : defaultBorder,
                focusedBorder: showError
                    ? errorBorder.copyWith(
                        borderSide: BorderSide(color: errorColor, width: 2))
                    : defaultBorder.copyWith(
                        borderSide: BorderSide(color: primary, width: 2)),
                errorBorder: errorBorder,
                focusedErrorBorder: errorBorder.copyWith(
                    borderSide: BorderSide(color: errorColor, width: 2),
                ),
            ),
            items: items,
            onChanged: onChanged,
            hint: Text(
                hintText,
                style: TextStyle(
                    color: showError ? errorColor : AppColors.textSecondary(context),
                    fontSize: 14,
                ),
            ),
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            dropdownColor: AppColors.surface(context),
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.iconPrimary(context)),
            isExpanded: true,
        );
    }

    static Widget buildReadout(String title, String content, {required BuildContext context}) {
        return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 2, offset: const Offset(0, 2)),
                ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary(context), fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(content, style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)), overflow: TextOverflow.ellipsis),
                ],
            ),
        );
    }

    static Widget buildReadout2(String content, Color color, {required BuildContext context}) {
        return Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.surfaceVariant(context),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 2, offset: const Offset(0, 1)),
                ],
            ),
            child: Text(content, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        );
    }

    static Future<void> showLottieDialog(
        BuildContext context, {
            required String lottiePath,
            String? message,
            Duration? autoCloseAfter,
        }) async {
        showGeneralDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black.withValues(alpha: 0.3),
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, __, ___) => const SizedBox.shrink(),
            transitionBuilder: (context, animation, _, __) {
                return FadeTransition(
                    opacity: animation,
                    child: Scaffold(
                        backgroundColor: Colors.transparent,
                        body: Center(
                            child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(20)),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                        child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.6),
                                            ),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                    SizedBox(
                                                        width: 100, height: 100,
                                                        child: Lottie.asset(lottiePath, fit: BoxFit.contain, repeat: true),
                                                    ),
                                                    if (message != null) const SizedBox(height: 16),
                                                    if (message != null)
                                                    Text(message, textAlign: TextAlign.center,
                                                        style: const TextStyle(color: AppColors.textPrimaryDark, fontSize: 12, fontWeight: FontWeight.w500)),
                                                ],
                                            ),
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
                );
            },
        );

        if (autoCloseAfter != null) {
            await Future.delayed(autoCloseAfter);
            if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        }
    }

    // ── Growing Phase — compact inline segmented control ─────────────────────
    static Widget buildGrowthPhaseSegmentedControl({
        required GrowingPhase? growthPhase,
        required bool showError,
        required ValueChanged<GrowingPhase> onChanged,
        required BuildContext context,
    }) {
        final phases = [
        {'value': GrowingPhase.BROODING_PHASE,           'label': 'Brooding',   'icon': Icons.egg_alt_rounded,    'color': AppColors.warning},
        {'value': GrowingPhase.GROWING_REARING_PHASE,    'label': 'Growing',    'icon': Icons.grass_rounded,      'color': AppColors.success},
        {'value': GrowingPhase.PRODUCTION_FINISHING_PHASE,'label': 'Production','icon': Icons.storefront_rounded, 'color': AppColors.info},
        ];

        final borderColor = showError
            ? AppColors.adaptiveError(context)
            : AppColors.adaptivePrimary(context).withAlpha(128);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                    'Growing Phase',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: showError ? AppColors.adaptiveError(context) : AppColors.adaptivePrimary(context),
                    ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                    height: 46,
                    child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                        ),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    for (int i = 0; i < phases.length; i++) ...[
                                            if (i > 0)
                                            Container(width: 1, color: borderColor),
                                            Expanded(
                                                child: GestureDetector(
                                                    onTap: () {
                                                        HapticFeedback.selectionClick();
                                                        onChanged(phases[i]['value'] as GrowingPhase);
                                                    },
                                                    child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 180),
                                                        color: growthPhase == phases[i]['value']
                                                            ? phases[i]['color'] as Color
                                                            : Colors.transparent,
                                                        child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                                Icon(
                                                                    phases[i]['icon'] as IconData,
                                                                    size: 16,
                                                                    color: growthPhase == phases[i]['value']
                                                                        ? Colors.white
                                                                        : AppColors.textSecondary(context),
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                    phases[i]['label'] as String,
                                                                    style: TextStyle(
                                                                        fontSize: 12,
                                                                        fontWeight: growthPhase == phases[i]['value']
                                                                            ? FontWeight.w700
                                                                            : FontWeight.w500,
                                                                        color: growthPhase == phases[i]['value']
                                                                            ? Colors.white
                                                                            : AppColors.textPrimary(context),
                                                                    ),
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ],
                                ],
                            ),
                        ),
                    ),
                ),
                if (showError)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Please select a growth phase',
                        style: TextStyle(color: AppColors.adaptiveError(context), fontSize: 12)),
                ),
            ],
        );
    }

    static Widget buildEggSizesRadioButtons({
        required EggSize? eggSize,
        required bool showError,
        required ValueChanged<EggSize> onChanged,
        required BuildContext context,
    }) {
        final eggSizes = [EggSize.LARGE, EggSize.MEDIUM, EggSize.PEEWEE, EggSize.SMALL, EggSize.EXTRA_LARGE, EggSize.JUMBO, EggSize.MIX_SIZE];
        final eggSizeLabels = {
            EggSize.LARGE: 'Large', EggSize.MEDIUM: 'Medium', EggSize.PEEWEE: 'Peewee',
            EggSize.SMALL: 'Small', EggSize.EXTRA_LARGE: 'XL', EggSize.JUMBO: 'Jumbo', EggSize.MIX_SIZE: 'Mix',
        };
        final scrollController = ScrollController();
        final ValueNotifier<double> scrollPosition = ValueNotifier(0);
        scrollController.addListener(() => scrollPosition.value = scrollController.offset);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text('Egg Size', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: showError ? AppColors.adaptiveError(context) : AppColors.adaptivePrimary(context))),
                const SizedBox(height: 6),
                Container(
                    decoration: showError
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.adaptiveError(context)),
                        )
                        : null,
                    padding: showError ? const EdgeInsets.all(6) : EdgeInsets.zero,
                    child: Column(
                        children: [
                            SingleChildScrollView(
                                controller: scrollController,
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                    children: eggSizes.map((entry) {
                                            final isSelected = eggSize == entry;
                                            return Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: GestureDetector(
                                                    onTap: () => onChanged(entry),
                                                    child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        decoration: BoxDecoration(
                                                            color: isSelected ? AppColors.adaptivePrimary(context) : AppColors.surfaceVariant(context),
                                                            borderRadius: BorderRadius.circular(16),
                                                            border: Border.all(
                                                                color: isSelected ? AppColors.adaptivePrimary(context) : AppColors.border(context),
                                                                width: 1.2),
                                                        ),
                                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                                                    size: 16, color: isSelected ? Colors.white : AppColors.textSecondary(context)),
                                                                const SizedBox(width: 6),
                                                                Text(eggSizeLabels[entry]!,
                                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                                                        color: isSelected ? Colors.white : AppColors.textPrimary(context))),
                                                            ]),
                                                    ),
                                                ),
                                            );
                                        }).toList(),
                                ),
                            ),
                            const SizedBox(height: 6),
                            ValueListenableBuilder<double>(
                                valueListenable: scrollPosition,
                                builder: (context, offset, child) {
                                    int visibleDots = 5;
                                    double totalWidth = eggSizes.length * 84;
                                    double maxScroll = totalWidth - MediaQuery.of(context).size.width;
                                    double progress = maxScroll > 0 ? (offset / maxScroll) : 0;
                                    int activeDot = (progress * (eggSizes.length - visibleDots)).round();
                                    return Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(eggSizes.length, (index) => Container(
                                                width: 6, height: 6,
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                decoration: BoxDecoration(shape: BoxShape.circle,
                                                    color: index == activeDot ? AppColors.adaptivePrimary(context) : AppColors.border(context)),
                                            )),
                                    );
                                },
                            ),
                        ],
                    ),
                ),
                if (showError)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Please select egg size', style: TextStyle(color: AppColors.adaptiveError(context), fontSize: 12)),
                ),
            ],
        );
    }

    static Widget buildBoxSizesWithScrollDots({
        required BoxSize? boxSize,
        required bool showError,
        required ValueChanged<BoxSize> onChanged,
        required BuildContext context,
    }) {
        final boxSizes = [BoxSize.THIRTY_EGGS_BOX, BoxSize.EIGHTEEN_EGGS_BOX, BoxSize.TWELVE_EGGS_BOX, BoxSize.SIX_EGGS_BOX];
        final boxSizeLabels = {
            BoxSize.THIRTY_EGGS_BOX: '30 Eggs', BoxSize.EIGHTEEN_EGGS_BOX: '18 Eggs',
            BoxSize.TWELVE_EGGS_BOX: '12 Eggs', BoxSize.SIX_EGGS_BOX: '6 Eggs',
        };
        final scrollController = ScrollController();
        final ValueNotifier<double> scrollPosition = ValueNotifier(0);
        scrollController.addListener(() => scrollPosition.value = scrollController.offset);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text('Box Size', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: showError ? AppColors.adaptiveError(context) : AppColors.adaptivePrimary(context))),
                const SizedBox(height: 6),
                Container(
                    decoration: showError
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.adaptiveError(context)),
                        )
                        : null,
                    padding: showError ? const EdgeInsets.all(6) : EdgeInsets.zero,
                    child: Column(
                        children: [
                            SingleChildScrollView(
                                controller: scrollController,
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                    children: boxSizes.map((entry) {
                                            final isSelected = boxSize == entry;
                                            return Padding(
                                                padding: const EdgeInsets.only(right: 8.0),
                                                child: GestureDetector(
                                                    onTap: () => onChanged(entry),
                                                    child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                        decoration: BoxDecoration(
                                                            color: isSelected ? AppColors.adaptivePrimary(context) : AppColors.surfaceVariant(context),
                                                            borderRadius: BorderRadius.circular(16),
                                                            border: Border.all(
                                                                color: isSelected ? AppColors.adaptivePrimary(context) : AppColors.border(context),
                                                                width: 1.2),
                                                        ),
                                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                                                Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                                                    size: 16, color: isSelected ? Colors.white : AppColors.textSecondary(context)),
                                                                const SizedBox(width: 6),
                                                                Text(boxSizeLabels[entry]!,
                                                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                                                        color: isSelected ? Colors.white : AppColors.textPrimary(context))),
                                                            ]),
                                                    ),
                                                ),
                                            );
                                        }).toList(),
                                ),
                            ),
                            const SizedBox(height: 6),
                            ValueListenableBuilder<double>(
                                valueListenable: scrollPosition,
                                builder: (context, offset, child) {
                                    int visibleDots = 3;
                                    double totalWidth = boxSizes.length * 80;
                                    double maxScroll = totalWidth - MediaQuery.of(context).size.width;
                                    double progress = maxScroll > 0 ? (offset / maxScroll) : 0;
                                    int activeDot = (progress * (boxSizes.length - visibleDots)).round();
                                    return Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(boxSizes.length, (index) => Container(
                                                width: 6, height: 6,
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                decoration: BoxDecoration(shape: BoxShape.circle,
                                                    color: index == activeDot ? AppColors.adaptivePrimary(context) : AppColors.border(context)),
                                            )),
                                    );
                                },
                            ),
                        ],
                    ),
                ),
                if (showError)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Please select box size', style: TextStyle(color: AppColors.adaptiveError(context), fontSize: 12)),
                ),
            ],
        );
    }

    // ── Coop Type — compact inline segmented control ─────────────────────────
    static Widget buildCoopTypeSegmentedControl({
        required String? selectedCoopType,
        required bool showError,
        required BuildContext context,
        required void Function(String) onChanged,
    }) {
        final types = [
        {'value': 'Broiler', 'label': 'Broiler', 'icon': Icons.set_meal_rounded, 'color': AppColors.warning},
        {'value': 'Layers',  'label': 'Layers',  'icon': Icons.egg_rounded,      'color': AppColors.success},
        ];

        final borderColor = showError
            ? AppColors.adaptiveError(context)
            : AppColors.adaptivePrimary(context).withAlpha(128);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                    'Coop Type',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: showError ? AppColors.adaptiveError(context) : AppColors.adaptivePrimary(context),
                    ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                    height: 46,
                    child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                        ),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    for (int i = 0; i < types.length; i++) ...[
                                            if (i > 0)
                                            Container(width: 1, color: borderColor),
                                            Expanded(
                                                child: GestureDetector(
                                                    onTap: () {
                                                        HapticFeedback.selectionClick();
                                                        onChanged(types[i]['value'] as String);
                                                    },
                                                    child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 180),
                                                        color: selectedCoopType == types[i]['value']
                                                            ? types[i]['color'] as Color
                                                            : Colors.transparent,
                                                        child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                                Icon(
                                                                    types[i]['icon'] as IconData,
                                                                    size: 18,
                                                                    color: selectedCoopType == types[i]['value']
                                                                        ? Colors.white
                                                                        : AppColors.textSecondary(context),
                                                                ),
                                                                const SizedBox(width: 6),
                                                                Text(
                                                                    types[i]['label'] as String,
                                                                    style: TextStyle(
                                                                        fontSize: 13,
                                                                        fontWeight: selectedCoopType == types[i]['value']
                                                                            ? FontWeight.w700
                                                                            : FontWeight.w500,
                                                                        color: selectedCoopType == types[i]['value']
                                                                            ? Colors.white
                                                                            : AppColors.textPrimary(context),
                                                                    ),
                                                                ),
                                                                if (selectedCoopType == types[i]['value']) ...[
                                                                    const SizedBox(width: 4),
                                                                    const Icon(Icons.check_circle, size: 14, color: Colors.white),
                                                                ],
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ],
                                ],
                            ),
                        ),
                    ),
                ),
                if (showError)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Please select a coop type',
                        style: TextStyle(color: AppColors.adaptiveError(context), fontSize: 12)),
                ),
            ],
        );
    }

    // ── Payment Status — compact inline segmented control ────────────────────
    static Widget buildPaymentStatusSegmentedControl({
        String? value,
        required bool showError,
        required BuildContext context,
        required void Function(String) onChanged,
    }) {
        final statuses = [
        {'value': 'Paid',    'label': 'Paid',    'icon': Icons.check_circle_rounded, 'color': AppColors.success},
        {'value': 'Pending', 'label': 'Pending', 'icon': Icons.schedule_rounded,     'color': AppColors.warning},
        ];

        final borderColor = showError
            ? AppColors.adaptiveError(context)
            : AppColors.adaptivePrimary(context).withAlpha(128);

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                    'Payment Status',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: showError ? AppColors.adaptiveError(context) : AppColors.adaptivePrimary(context),
                    ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                    height: 46,
                    child: Container(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                        ),
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                    for (int i = 0; i < statuses.length; i++) ...[
                                            if (i > 0)
                                            Container(width: 1, color: borderColor),
                                            Expanded(
                                                child: GestureDetector(
                                                    onTap: () {
                                                        HapticFeedback.selectionClick();
                                                        onChanged(statuses[i]['value'] as String);
                                                    },
                                                    child: AnimatedContainer(
                                                        duration: const Duration(milliseconds: 180),
                                                        color: value == statuses[i]['value']
                                                            ? statuses[i]['color'] as Color
                                                            : Colors.transparent,
                                                        child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.center,
                                                            crossAxisAlignment: CrossAxisAlignment.center,
                                                            children: [
                                                                Icon(
                                                                    statuses[i]['icon'] as IconData,
                                                                    size: 18,
                                                                    color: value == statuses[i]['value']
                                                                        ? Colors.white
                                                                        : AppColors.textSecondary(context),
                                                                ),
                                                                const SizedBox(width: 6),
                                                                Text(
                                                                    statuses[i]['label'] as String,
                                                                    style: TextStyle(
                                                                        fontSize: 13,
                                                                        fontWeight: value == statuses[i]['value']
                                                                            ? FontWeight.w700
                                                                            : FontWeight.w500,
                                                                        color: value == statuses[i]['value']
                                                                            ? Colors.white
                                                                            : AppColors.textPrimary(context),
                                                                    ),
                                                                ),
                                                                if (value == statuses[i]['value']) ...[
                                                                    const SizedBox(width: 4),
                                                                    const Icon(Icons.check_circle, size: 14, color: Colors.white),
                                                                ],
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ],
                                ],
                            ),
                        ),
                    ),
                ),
                if (showError)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Please select payment status',
                        style: TextStyle(color: AppColors.adaptiveError(context), fontSize: 12)),
                ),
            ],
        );
    }
}

// ── Private: Text field with inline validation state ─────────────────────────
class _AppTextField extends StatefulWidget {
    final String label;
    final IconData icon;
    final void Function(String) onChanged;
    final String? Function(String?)? validator;
    final TextInputType? keyboardType;
    final String? initialValue;
    final bool isPassword;

    const _AppTextField({
        required this.label,
        required this.icon,
        required this.onChanged,
        this.validator,
        this.keyboardType,
        this.initialValue,
        this.isPassword = false,
    });

    @override
    State<_AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<_AppTextField> {
    bool _obscureText = true;
    bool? _isValid;

    @override
    Widget build(BuildContext context) {
        final primary = AppColors.adaptivePrimary(context);
        final errorColor = AppColors.adaptiveError(context);

        final defaultBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary.withAlpha(128)),
        );
        final validBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.success, width: 1.5),
        );
        final activeBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary, width: 2),
        );
        final errorBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: errorColor),
        );

        return TextFormField(
            initialValue: widget.initialValue,
            obscureText: widget.isPassword && _obscureText,
            keyboardType: widget.keyboardType,
            onChanged: (value) {
                final valid = widget.validator != null
                    ? (widget.validator!(value) == null && value.isNotEmpty)
                    : value.isNotEmpty;
                if (_isValid != valid) setState(() => _isValid = valid);
                widget.onChanged(value);
            },
            validator: widget.validator,
            decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: TextStyle(
                    fontSize: 14,
                    color: _isValid == true ? AppColors.success : null,
                ),
                prefixIcon: Icon(widget.icon, color: AppColors.iconPrimary(context)),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: defaultBorder,
                enabledBorder: _isValid == true ? validBorder : defaultBorder,
                focusedBorder: _isValid == true
                    ? validBorder.copyWith(borderSide: const BorderSide(color: AppColors.success, width: 2))
                    : activeBorder,
                errorBorder: errorBorder,
                focusedErrorBorder: errorBorder.copyWith(borderSide: BorderSide(color: errorColor, width: 2)),
                errorStyle: TextStyle(color: errorColor, fontSize: 12),
                suffixIcon: widget.isPassword
                    ? IconButton(
                        icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility,
                            color: AppColors.textSecondary(context)),
                        onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                    : (_isValid == true
                        ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                        : null),
            ),
        );
    }
}

// ── Private: Currency field with thousand-separator formatting ────────────────
class _AppCurrencyField extends StatefulWidget {
    final String label;
    final void Function(double) onChanged;
    final String? Function(String?)? validator;
    final double initialValue;
    final String currencySymbol;

    const _AppCurrencyField({
        required this.label,
        required this.onChanged,
        this.validator,
        this.initialValue = 0,
        this.currencySymbol = 'R',
    });

    @override
    State<_AppCurrencyField> createState() => _AppCurrencyFieldState();
}

class _AppCurrencyFieldState extends State<_AppCurrencyField> {
    late TextEditingController _controller;
    bool? _isValid;

    static double _parse(String text) {
        final cleaned = text.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '');
        return double.tryParse(cleaned) ?? 0;
    }

    static String _formatInitial(double value) {
        if (value <= 0) return '';
        return NumberFormat('#,##0.##').format(value);
    }

    @override
    void initState() {
        super.initState();
        _controller = TextEditingController(text: _formatInitial(widget.initialValue));
    }

    @override
    void dispose() {
        _controller.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final primary = AppColors.adaptivePrimary(context);
        final errorColor = AppColors.adaptiveError(context);
        final defaultBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary.withAlpha(128)),
        );
        final validBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.success, width: 1.5),
        );
        final activeBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primary, width: 2),
        );
        final errorBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: errorColor),
        );

        return TextFormField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_CurrencyInputFormatter()],
            onChanged: (value) {
                final parsed = _parse(value);
                widget.onChanged(parsed);
                final valid = widget.validator != null
                    ? (widget.validator!(value) == null && value.isNotEmpty)
                    : (parsed > 0);
                if (_isValid != valid) setState(() => _isValid = valid);
            },
            validator: (value) {
                if (widget.validator != null) return widget.validator!(value);
                final parsed = _parse(value ?? '');
                if (parsed <= 0) return 'Please enter a valid amount';
                return null;
            },
            decoration: InputDecoration(
                labelText: widget.label,
                labelStyle: TextStyle(
                    fontSize: 14,
                    color: _isValid == true ? AppColors.success : null,
                ),
                prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    child: Text(widget.currencySymbol,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                            color: _isValid == true ? AppColors.success : primary)),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: defaultBorder,
                enabledBorder: _isValid == true ? validBorder : defaultBorder,
                focusedBorder: _isValid == true
                    ? validBorder.copyWith(borderSide: const BorderSide(color: AppColors.success, width: 2))
                    : activeBorder,
                errorBorder: errorBorder,
                focusedErrorBorder: errorBorder.copyWith(borderSide: BorderSide(color: errorColor, width: 2)),
                errorStyle: TextStyle(color: errorColor, fontSize: 12),
                suffixIcon: _isValid == true
                    ? const Icon(Icons.check_circle, color: AppColors.success, size: 20)
                    : null,
            ),
        );
    }
}

// ── Private: Currency input formatter ─────────────────────────────────────────
class _CurrencyInputFormatter extends TextInputFormatter {
    @override
    TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
        if (newValue.text.isEmpty) return newValue;
        final cleaned = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
        // Prevent multiple decimal points
        if (cleaned.split('.').length > 2) return oldValue;
        final parts = cleaned.split('.');
        final intPart = parts[0];
        final hasDot = cleaned.contains('.');
        final decPart = parts.length > 1 ? parts[1] : '';
        final limitedDec = decPart.length > 2 ? decPart.substring(0, 2) : decPart;
        String formattedInt = '';
        if (intPart.isNotEmpty) {
            final intValue = int.tryParse(intPart) ?? 0;
            formattedInt = NumberFormat('#,##0').format(intValue);
        }
        final formatted = hasDot ? '$formattedInt.$limitedDec' : formattedInt;
        return TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
        );
    }
}

// ── Private: Stepper field with +/− buttons ───────────────────────────────────
class _StepperField extends StatefulWidget {
    final String label;
    final int initialValue;
    final void Function(int) onChanged;
    final int min;
    final int max;
    final bool showError;
    final String? errorText;

    const _StepperField({
        required this.label,
        required this.initialValue,
        required this.onChanged,
        this.min = 0,
        this.max = 99999,
        this.showError = false,
        this.errorText,
    });

    @override
    State<_StepperField> createState() => _StepperFieldState();
}

class _StepperFieldState extends State<_StepperField> {
    late int _value;
    late TextEditingController _controller;

    @override
    void initState() {
        super.initState();
        _value = widget.initialValue;
        _controller = TextEditingController(text: _value.toString());
    }

    @override
    void didUpdateWidget(_StepperField old) {
        super.didUpdateWidget(old);
        if (old.initialValue != widget.initialValue && _value == old.initialValue) {
            _value = widget.initialValue;
            _controller.text = _value.toString();
        }
    }

    @override
    void dispose() {
        _controller.dispose();
        super.dispose();
    }

    void _increment() {
        if (_value < widget.max) {
            HapticFeedback.lightImpact();
            setState(() {
                    _value++;
                    _controller.text = _value.toString();
                });
            widget.onChanged(_value);
        }
    }

    void _decrement() {
        if (_value > widget.min) {
            HapticFeedback.lightImpact();
            setState(() {
                    _value--;
                    _controller.text = _value.toString();
                });
            widget.onChanged(_value);
        }
    }

    @override
    Widget build(BuildContext context) {
        final primary = AppColors.adaptivePrimary(context);
        final errorColor = AppColors.adaptiveError(context);
        final bool isValid = _value > widget.min;

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(widget.label,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                        color: widget.showError ? errorColor : primary)),
                const SizedBox(height: 6),
                Container(
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: widget.showError
                                ? errorColor
                                : isValid
                                    ? AppColors.success
                                    : primary.withAlpha(128),
                            width: isValid ? 1.5 : 1,
                        ),
                    ),
                    child: Row(
                        children: [
                            // Decrement button
                            Material(
                                color: Colors.transparent,
                                child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                    onTap: _value > widget.min ? _decrement : null,
                                    child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(Icons.remove,
                                            color: _value > widget.min ? primary : AppColors.textTertiary(context),
                                            size: 20),
                                    ),
                                ),
                            ),
                            // Value input
                            Expanded(
                                child: TextFormField(
                                    controller: _controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary(context)),
                                    decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (v) {
                                        final parsed = int.tryParse(v);
                                        if (parsed != null && parsed >= widget.min && parsed <= widget.max) {
                                            setState(() => _value = parsed);
                                            widget.onChanged(_value);
                                        }
                                    },
                                ),
                            ),
                            // Increment button
                            Material(
                                color: Colors.transparent,
                                child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                    onTap: _value < widget.max ? _increment : null,
                                    child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(Icons.add,
                                            color: _value < widget.max ? primary : AppColors.textTertiary(context),
                                            size: 20),
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
                if (isValid && !widget.showError)
                Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Row(children: [
                            const Icon(Icons.check_circle, color: AppColors.success, size: 14),
                            const SizedBox(width: 4),
                            Text('$_value entered', style: const TextStyle(color: AppColors.success, fontSize: 11)),
                        ]),
                ),
                if (widget.showError && widget.errorText != null)
                Padding(
                    padding: const EdgeInsets.only(top: 4, left: 2),
                    child: Text(widget.errorText!, style: TextStyle(color: errorColor, fontSize: 12)),
                ),
            ],
        );
    }
}
