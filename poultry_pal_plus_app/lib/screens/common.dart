import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:lottie/lottie.dart';
import 'package:poultry_pal_plus_app/models/box_size.dart';
import '../models/egg_size.dart';
import '../models/growing_phase.dart';

class Common {
    static SnackBar buildSnackBar(String message, Color backgroundColor) {
        return SnackBar(
            content: Row(
                mainAxisAlignment: MainAxisAlignment.start, // Align to the start
                children: [
                    const Icon(Icons.check_circle, color: AppColors.surfaceLight),
                    const SizedBox(width: 10),
                    Expanded(
                        // Wrap text with Expanded
                        child: Text(
                            message,
                            style: const TextStyle(color: AppColors.surfaceLight),
                            textAlign: TextAlign.start, // Align text to the start
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
        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withAlpha(128),
            ),
        );

        final focusedBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2.0,
            ),
        );

        // Return a StatefulBuilder to isolate visibility toggle
        return StatefulBuilder(
            builder: (BuildContext context, void Function(void Function()) setState) {
                bool obscureText = isPassword;

                return StatefulBuilder(
                    builder: (context, setState) {
                        return TextFormField(
                            initialValue: initialValue,
                            obscureText: obscureText,
                            onChanged: onChanged,
                            validator: validator,
                            keyboardType: keyboardType,
                            decoration: InputDecoration(
                                labelText: label,
                                labelStyle: const TextStyle(fontSize: 14),
                                prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
                                contentPadding:
                                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                border: border,
                                enabledBorder: border,
                                focusedBorder: focusedBorder,
                                errorBorder: border.copyWith(
                                    borderSide: const BorderSide(color: AppColors.error),
                                ),
                                focusedErrorBorder: border.copyWith(
                                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                                ),
                                suffixIcon: isPassword
                                    ? IconButton(
                                        icon: Icon(
                                            obscureText ? Icons.visibility_off : Icons.visibility,
                                            color: AppColors.textSecondaryLight,
                                        ),
                                        onPressed: () {
                                            setState(() {
                                                    obscureText = !obscureText;
                                                });
                                        },
                                    )
                                    : null,
                            ),
                        );
                    },
                );
            },
        );
    }

    static Widget buildCoopTypeDropdownField({
        required String value,
        required void Function(String?) onChanged,
        String? Function(String?)? validator,
        required BuildContext context,
    }) {
        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
            ),
        );

        return DropdownButtonFormField<String>(
            decoration: InputDecoration(
                labelText: 'Coop Type',
                prefixIcon: Icon(
                    Icons.category_outlined,
                    color: Theme.of(context).primaryColor,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: border,
                enabledBorder: border,
                focusedBorder: border.copyWith(
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                errorBorder: border.copyWith(
                    borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: border.copyWith(
                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
            ),
            value: value,
            onChanged: onChanged,
            validator: validator,
            menuMaxHeight: 250, // Avoid floating off-screen
            isExpanded: true,   // Prevent clipping inside sheets
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
        final mortalityReasons = {
            'Select expense type': '',
            'Feed Costs':
            'Includes expenses for purchasing feed for chickens, which is often the largest ongoing cost in poultry farming. Feed costs vary based on chicken types (broilers vs. layers) and the quality and quantity of feed required.',
            'Chicks or Hatching Eggs':
            'The initial cost of purchasing day-old chicks or hatching eggs. This can be a one-time cost if breeding is done on-site but recurring if chicks or eggs are purchased regularly.',
            'Housing and Coop Maintenance':
            'Covers expenses for building, maintaining, and upgrading chicken coops and housing. This includes materials like wood, wire mesh, nesting boxes, and equipment to ensure a secure and comfortable environment for poultry.',
            'Vaccination and Medications':
            'Expenses for vaccines, antibiotics, and other medications to prevent diseases and keep poultry healthy. It may also include routine veterinary checkups and consultation costs.',
            'Heating, Cooling, and Ventilation':
            'The cost of maintaining optimal temperature and ventilation in coops. This can include heating lamps, fans, or other systems to control the coop environment, especially important for young chicks and during extreme weather.',
            'Water Supply and Equipment':
            'Expenses for maintaining a constant water supply, including water dispensers, pumps, and purifiers if needed. Clean water is essential for poultry health and productivity.',
            'Labor Costs':
            'Costs associated with hiring workers or laborers for feeding, cleaning, managing, and monitoring poultry operations. This may be a significant expense if the farm is large or requires specialized labor.',
            'Electricity and Utilities':
            'Utility costs for powering equipment, lights, heating, cooling, and any other electrical appliances used on the farm.',
            'Transportation and Delivery':
            'Costs involved in transporting supplies to the farm, moving chickens to markets, or delivering products such as eggs or meat to customers.',
            'Cleaning and Biosecurity Supplies':
            'Expenses for cleaning products, disinfectants, and biosecurity measures to maintain a hygienic environment and prevent disease spread.',
            'Insurance and Licensing':
            'Costs for insuring the farm, livestock, and equipment. It also includes any licensing or regulatory fees required to operate legally.',
            'Bedding and Nesting Material':
            'Recurring costs for bedding materials like straw, shavings, or sand that need to be replaced periodically to maintain coop hygiene.',
            'Breeding Costs':
            'Costs related to breeding programs, such as expenses for breeding stock, incubators, and brooding equipment if chicks are hatched on-site.',
            'Marketing and Sales Expenses':
            'Expenses for advertising, promotions, or packaging materials if you are selling eggs, meat, or other poultry products directly to customers.',
            'Equipment and Tools':
            'One-time or recurring costs for essential equipment like feeders, waterers, cleaning tools, egg collection trays, scales, and cages.',
            'Waste Disposal':
            'Costs related to disposing of poultry waste, dead birds, or unused materials, including composting or waste management services.',
            'Record-Keeping and Software':
            'If using specialized software or hiring services for record-keeping, production monitoring, and financial tracking, this would include subscription fees or consulting costs.',
            'Miscellaneous Supplies':
            'Other small expenses that don’t fall into the categories above, such as gloves, feed bags, or tools that need periodic replacement.',
        };

        return DropdownButtonFormField<String>(
            decoration: InputDecoration(
                labelText: 'Expense Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            ),
            value: value,
            onChanged: onChanged,
            validator: validator,
            items: mortalityReasons.entries.map((entry) {
                    //bool isSelected = entry.key == value;  // Check if this entry is selected
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
                                    Row(
                                        children: [
                                            Icon(
                                                Icons.category_outlined,
                                                color: Theme.of(context).primaryColor,
                                            ),
                                            const SizedBox(width: 10),
                                        ],
                                    )
                                    else if (entry.value.isNotEmpty &&
                                        entry.key != 'Select expense type')
                                    Row(
                                        children: [
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
                                                                        onPressed: () {
                                                                            Navigator.of(context).pop();
                                                                        },
                                                                        child: const Text("Close"),
                                                                    ),
                                                                ],
                                                            );
                                                        },
                                                    );
                                                },
                                                child: const Icon(
                                                    Icons.info_outline,
                                                    color: AppColors.info,
                                                ),
                                            ),
                                            const SizedBox(width: 10),
                                        ],
                                    ),
                                    Flexible(
                                        child: Text(
                                            entry.key,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.normal,
                                                fontSize: 14,
                                                color: Colors.black, // Default color
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
    }) {
        final borderColor = hasError
            ? AppColors.error
            : Theme.of(context).primaryColor.withAlpha(128);

        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor),
        );

        return InkWell(
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
                        color: hasError ? AppColors.error : Theme.of(context).primaryColor,
                        fontSize: 14,
                    ),
                    prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).primaryColor,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border.copyWith(
                        borderSide: BorderSide(
                            color: hasError ? AppColors.error : Theme.of(context).primaryColor,
                            width: 2,
                        ),
                    ),
                ),
                child: Text(
                    date != null
                        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                        : 'Select date',
                    style: TextStyle(
                        fontSize: 14,
                        color: date != null
                            ? AppColors.textPrimaryLight
                            : (hasError ? AppColors.error : Colors.black),
                    ),
                ),

            ),
        );
    }

    static Widget buildDropdown({
        required String? selectedValue,
        required List<DropdownMenuItem<String>> items,
        required ValueChanged<String?> onChanged,
        String hintText = 'Select an option',
    }) {
        return Container(
            margin: const EdgeInsets.symmetric(vertical: 6), // Consistent spacing with readout
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Compact padding
            decoration: BoxDecoration(
                color: AppColors.surfaceVariantLight, // Subtle background color
                borderRadius: BorderRadius.circular(8), // Rounded corners
                boxShadow: [
                    BoxShadow(
                        color: AppColors.textTertiaryLight.withOpacity(0.1), // Minimal shadow for depth
                        blurRadius: 4,
                        offset: const Offset(0, 2), // Light shadow offset
                    ),
                ],
            ),
            child: DropdownButtonFormField<String>(
                value: selectedValue,
                decoration: const InputDecoration(
                    border: InputBorder.none, // Remove default border
                    isDense: true, // Compact form field
                    contentPadding: EdgeInsets.zero, // Adjust padding
                ),
                items: items,
                onChanged: onChanged,
                hint: Text(
                    hintText,
                    style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 14,
                    ),
                ),
                style: const TextStyle(
                    color: AppColors.textPrimaryLight,
                    fontSize: 14,
                ),
                dropdownColor: AppColors.surfaceLight, // Dropdown background color
                icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppColors.textSecondaryLight,
                ),
            ),
        );
    }

    static Widget buildReadout(String title, String content) {
        return Container(
            width: double.infinity, // Fills the width of the screen
            margin: const EdgeInsets.symmetric(vertical: 6), // Slight vertical spacing
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Compact padding
            decoration: BoxDecoration(
                color: AppColors.surfaceVariantLight, // Subtle background color
                borderRadius: BorderRadius.circular(8), // Rounded corners
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5), // Soft, minimal shadow
                        blurRadius: 2,
                        offset: const Offset(0, 2), // Light shadow offset
                    ),
                ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                        title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondaryLight,
                            fontSize: 12,
                        ),
                    ),
                    const SizedBox(height: 2), // Reduced spacing
                    Text(
                        content,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimaryLight,
                        ),
                        overflow: TextOverflow.ellipsis,
                    ),
                ],
            ),
        );
    }

    static Widget buildReadout2(String content, Color color) {
        return Container(
            width: double.infinity, // Fills the width of the screen
            margin: const EdgeInsets.symmetric(vertical: 6), // Slight vertical spacing
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Compact padding
            decoration: BoxDecoration(
                color: AppColors.surfaceVariantLight, // Subtle background color
                borderRadius: BorderRadius.circular(8), // Rounded corners
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5), // Soft, minimal shadow
                        blurRadius: 2,
                        offset: const Offset(0, 1), // Light shadow offset
                    ),
                ],
            ),
            child: Text(
                content,
                style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.bold,
                ),
            ),
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
            barrierColor: Colors.black.withOpacity(0.3),
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
                                decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(20),
                                ),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                        child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(20),
                                                border: Border.all(
                                                    color: Colors.white.withOpacity(0.1),
                                                    width: 0.6,
                                                ),
                                            ),
                                            child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                    // Fixed size box for Lottie animation
                                                    SizedBox(
                                                        width: 100,
                                                        height: 100,
                                                        child: Lottie.asset(
                                                            lottiePath,
                                                            fit: BoxFit.contain,
                                                            repeat: true,
                                                        ),
                                                    ),
                                                    if (message != null)
                                                    const SizedBox(height: 16),
                                                    if (message != null)
                                                    Text(
                                                        message,
                                                        textAlign: TextAlign.center,
                                                        style: const TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.w500,
                                                        ),
                                                    ),
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
            if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pop();
            }
        }
    }

    static Widget buildGrowthPhaseSegmentedControl({
        required GrowingPhase growthPhase,
        required bool showError,
        required ValueChanged<GrowingPhase> onChanged,
        required BuildContext context,
    }) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                    'Growing Phase',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: showError ? AppColors.error : Theme.of(context).primaryColor,
                    ),
                ),
                const SizedBox(height: 6),
                Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: showError
                                ? AppColors.error
                                : Theme.of(context).primaryColor.withAlpha(128),
                            width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: CupertinoSegmentedControl<GrowingPhase>(
                        padding: const EdgeInsets.all(4),
                        groupValue: growthPhase,
                        onValueChanged: onChanged,
                        children: {
                            GrowingPhase.BROODING_PHASE: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                    'Brooding',
                                    style: TextStyle(
                                        color: growthPhase == GrowingPhase.BROODING_PHASE
                                            ? Colors.white
                                            : Colors.black,
                                    ),
                                ),
                            ),
                            GrowingPhase.GROWING_REARING_PHASE: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                    'Growing',
                                    style: TextStyle(
                                        color: growthPhase == GrowingPhase.GROWING_REARING_PHASE
                                            ? Colors.white
                                            : Colors.black,
                                    ),
                                ),
                            ),
                            GrowingPhase.PRODUCTION_FINISHING_PHASE: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(
                                    'Production',
                                    style: TextStyle(
                                        color: growthPhase == GrowingPhase.PRODUCTION_FINISHING_PHASE
                                            ? Colors.white
                                            : Colors.black,
                                    ),
                                ),
                            ),
                        },
                        borderColor: AppColors.borderLight,
                        selectedColor: AppColors.primary,
                        unselectedColor: Colors.white,
                        pressedColor: AppColors.surfaceVariantLight,
                    ),
                ),
                if (showError)
                const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                        'Please select a growth phase',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                        ),
                    ),
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
        final eggSizes = [
            EggSize.LARGE,
            EggSize.MEDIUM,
            EggSize.PEEWEE,
            EggSize.SMALL,
            EggSize.EXTRA_LARGE,
            EggSize.JUMBO,
            EggSize.MIX_SIZE,
        ];

        final eggSizeLabels = {
            EggSize.LARGE: 'Large',
            EggSize.MEDIUM: 'Medium',
            EggSize.PEEWEE: 'Peewee',
            EggSize.SMALL: 'Small',
            EggSize.EXTRA_LARGE: 'XL',
            EggSize.JUMBO: 'Jumbo',
            EggSize.MIX_SIZE: 'Mix',
        };

        final scrollController = ScrollController();
        ValueNotifier<double> scrollPosition = ValueNotifier(0);

        scrollController.addListener(() {
                scrollPosition.value = scrollController.offset;
            });

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                    'Egg Size',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: showError ? AppColors.error : Theme.of(context).primaryColor,
                    ),
                ),
                const SizedBox(height: 6),
                Column(
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
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                        color: isSelected ? AppColors.primary : AppColors.surfaceVariantLight,
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(
                                                            color: isSelected
                                                                ? AppColors.primary
                                                                : AppColors.borderLight,
                                                            width: 1.2,
                                                        ),
                                                    ),
                                                    child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                            Icon(
                                                                isSelected
                                                                    ? Icons.radio_button_checked
                                                                    : Icons.radio_button_off,
                                                                size: 16,
                                                                color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                                eggSizeLabels[entry]!,
                                                                style: TextStyle(
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ),
                                        );
                                    }).toList(),
                            ),
                        ),
                        const SizedBox(height: 6),
                        // Scroll dots indicator
                        ValueListenableBuilder<double>(
                            valueListenable: scrollPosition,
                            builder: (context, offset, child) {
                                // Determine number of dots
                                int visibleDots = 5; // Show 5 dots maximum
                                double totalWidth =
                                    eggSizes.length * 84; // Approx width of each chip + spacing
                                double maxScroll = totalWidth - MediaQuery.of(context).size.width;
                                double progress =
                                    maxScroll > 0 ? (offset / maxScroll) : 0; // 0..1
                                int activeDot = (progress * (eggSizes.length - visibleDots)).round();

                                return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(eggSizes.length, (index) {
                                            return Container(
                                                width: 6,
                                                height: 6,
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: index == activeDot
                                                        ? AppColors.primary
                                                        : AppColors.borderLight,
                                                ),
                                            );
                                        }),
                                );
                            },
                        ),
                    ],
                ),
                if (showError)
                const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                        'Please select egg size',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                        ),
                    ),
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
        final boxSizes = [
            BoxSize.THIRTY_EGGS_BOX,
            BoxSize.EIGHTEEN_EGGS_BOX,
            BoxSize.TWELVE_EGGS_BOX,
            BoxSize.SIX_EGGS_BOX,
        ];

        final boxSizeLabels = {
            BoxSize.THIRTY_EGGS_BOX: '30 Eggs',
            BoxSize.EIGHTEEN_EGGS_BOX: '18 Eggs',
            BoxSize.TWELVE_EGGS_BOX: '12 Eggs',
            BoxSize.SIX_EGGS_BOX: '6 Eggs',
        };

        final scrollController = ScrollController();
        ValueNotifier<double> scrollPosition = ValueNotifier(0);

        scrollController.addListener(() {
                scrollPosition.value = scrollController.offset;
            });

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Text(
                    'Box Size',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: showError ? AppColors.error : Theme.of(context).primaryColor,
                    ),
                ),
                const SizedBox(height: 6),
                Column(
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
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12, vertical: 8),
                                                    decoration: BoxDecoration(
                                                        color: isSelected ? AppColors.primary : AppColors.surfaceVariantLight,
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(
                                                            color: isSelected
                                                                ? AppColors.primary
                                                                : AppColors.borderLight,
                                                            width: 1.2,
                                                        ),
                                                    ),
                                                    child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                            Icon(
                                                                isSelected
                                                                    ? Icons.radio_button_checked
                                                                    : Icons.radio_button_off,
                                                                size: 16,
                                                                color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                                boxSizeLabels[entry]!,
                                                                style: TextStyle(
                                                                    fontSize: 13,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ),
                                        );
                                    }).toList(),
                            ),
                        ),
                        const SizedBox(height: 6),
                        // Scroll dots indicator
                        ValueListenableBuilder<double>(
                            valueListenable: scrollPosition,
                            builder: (context, offset, child) {
                                // Determine number of dots
                                int visibleDots = 3; // Show max 3 dots for limited options
                                double totalWidth = boxSizes.length * 80; // Approx chip width + spacing
                                double maxScroll = totalWidth - MediaQuery.of(context).size.width;
                                double progress = maxScroll > 0 ? (offset / maxScroll) : 0;
                                int activeDot =
                                    (progress * (boxSizes.length - visibleDots)).round();

                                return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(boxSizes.length, (index) {
                                            return Container(
                                                width: 6,
                                                height: 6,
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: index == activeDot
                                                        ? AppColors.primary
                                                        : AppColors.borderLight,
                                                ),
                                            );
                                        }),
                                );
                            },
                        ),
                    ],
                ),
                if (showError)
                const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                        'Please select box size',
                        style: TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                        ),
                    ),
                ),
            ],
        );
    }

    static Widget buildCoopTypeSegmentedControl({
        required String? selectedCoopType,
        required bool showError,
        required BuildContext context,
        required void Function(String) onChanged,
    }) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                        'Select Coop Type',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: showError ? AppColors.error : Theme.of(context).primaryColor,
                        ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: showError
                                    ? AppColors.error
                                    : Theme.of(context).primaryColor.withAlpha(128),
                                width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CupertinoSegmentedControl<String>(
                            padding: const EdgeInsets.all(4),
                            groupValue: selectedCoopType,
                            onValueChanged: (val) => onChanged(val),
                            children: {
                                'Broiler': Padding(
                                    padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                        'Broiler',
                                        style: TextStyle(
                                            color: selectedCoopType == 'Broiler'
                                                ? Colors.white
                                                : Colors.black,
                                        ),
                                    ),
                                ),
                                'Layers': Padding(
                                    padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                        'Layers',
                                        style: TextStyle(
                                            color: selectedCoopType == 'Layers'
                                                ? Colors.white
                                                : Colors.black,
                                        ),
                                    ),
                                ),
                            },
                            borderColor: AppColors.borderLight,
                            selectedColor: AppColors.primary,
                            unselectedColor: Colors.white,
                            pressedColor: AppColors.surfaceVariantLight,
                        ),
                    ),
                    if (showError)
                    const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                            'Please select a coop type',
                            style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    static Widget buildPaymentStatusSegmentedControl({
        String? value,
        required bool showError,
        required BuildContext context,
        required void Function(String) onChanged,
    }) {
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                        'Payment Status',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: showError ? AppColors.error : Theme.of(context).primaryColor,
                        ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: showError
                                    ? AppColors.error
                                    : Theme.of(context).primaryColor.withAlpha(128),
                                width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CupertinoSegmentedControl<String>(
                            padding: const EdgeInsets.all(4),
                            groupValue: value,
                            onValueChanged: (val) => onChanged(val),
                            children: {
                                'Paid': Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                        'Paid',
                                        style: TextStyle(
                                            color: value == 'Paid' ? Colors.white : Colors.black,
                                        ),
                                    ),
                                ),
                                'Pending': Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    child: Text(
                                        'Pending',
                                        style: TextStyle(
                                            color: value == 'Pending' ? Colors.white : Colors.black,
                                        ),
                                    ),
                                ),
                            },
                            borderColor: AppColors.borderLight,
                            selectedColor: AppColors.primary,
                            unselectedColor: Colors.white,
                            pressedColor: AppColors.surfaceVariantLight,
                        ),
                    ),
                    if (showError)
                    const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                            'Please select payment status',
                            style: TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

}

