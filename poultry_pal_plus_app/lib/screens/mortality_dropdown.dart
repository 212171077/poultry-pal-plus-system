import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class MortalityDropdown extends StatelessWidget {
    final String value;
    final void Function(String?) onChanged;
    final String? Function(String?)? validator;
    final bool hasSubmitted;

    const MortalityDropdown({
        super.key,
        required this.value,
        required this.onChanged,
        required this.hasSubmitted,
        this.validator,
    });

    @override
    Widget build(BuildContext context) {
        final mortalityReasons = {
            'Select mortality reason': '',
            'Diseases': 'Common Diseases: Newcastle disease, avian influenza, infectious bronchitis, coccidiosis, and Marek\'s disease.',
            'Poor Nutrition': 'Cause: Nutritional deficiencies or poor-quality feed.',
            'Environmental Stress': 'Cause: Extreme temperatures, inadequate ventilation, and overcrowding.',
            'Parasites': 'Common Types: Internal (worms) and external parasites (mites, lice).',
            'Poor Hygiene & Sanitation': 'Cause: Dirty water, bedding, or litter.',
            'Genetic Factors': 'Cause: Breeds prone to health issues or stress.',
            'Poor Handling & Transportation': 'Cause: Rough handling or overcrowding during transport.',
            'Predators': 'Common Predators: Foxes, hawks, raccoons, and stray dogs.',
            'Cannibalism and Pecking': 'Cause: Overcrowding, poor lighting, and boredom.',
            'Water & Feed Issues': 'Cause: Contaminated water or poor-quality feed.',
            'Sudden Death Syndrome': 'Cause: Mainly affects broilers due to high growth rates.',
            'Overcrowding': 'Cause: Stress, disease transmission, and resource competition.',
            'Toxins & Poisoning': 'Cause: Exposure to toxic plants, pesticides, or chemicals.',
        };

        final isPlaceholderSelected = value == 'Select mortality reason';
        final isInvalid = isPlaceholderSelected && hasSubmitted;
        final primary = AppColors.adaptivePrimary(context);
        final errorColor = AppColors.adaptiveError(context);

        final border = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: AppColors.adaptivePrimary(context).withAlpha(128),
            ),
        );

        final focusedBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
                color: AppColors.adaptivePrimary(context),
                width: 2.0,
            ),
        );

        return DropdownButtonFormField2<String>(
            isExpanded: true,
            value: value,
            onChanged: (val) {
                if (val != 'Select mortality reason') {
                    onChanged(val);
                }
            },
            validator: validator,
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
            iconStyleData: IconStyleData(
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.iconPrimary(context)),
            ),
            decoration: InputDecoration(
                labelText: 'Mortality Reason',
                labelStyle: TextStyle(fontSize: 14, color: isInvalid ? errorColor : primary),
                prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 0),
                    child: Icon(Icons.category_outlined, color: AppColors.adaptivePrimary(context)),
                ),
                prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                filled: true,
                fillColor: AppColors.surfaceVariant(context),
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
                errorBorder: border.copyWith(
                    borderSide: BorderSide(color: errorColor),
                ),
                focusedErrorBorder: border.copyWith(
                    borderSide: BorderSide(color: errorColor, width: 2),
                ),
            ),
            dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.adaptivePrimary(context).withAlpha(60)),
                    boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                        ),
                    ],
                ),
                scrollbarTheme: ScrollbarThemeData(
                    thumbColor: WidgetStateProperty.all(
                        AppColors.adaptivePrimary(context).withAlpha(100)),
                    thickness: WidgetStateProperty.all(4),
                    radius: const Radius.circular(4),
                ),
            ),
            menuItemStyleData: const MenuItemStyleData(
                height: 48,
                padding: EdgeInsets.symmetric(horizontal: 8),
            ),
            selectedItemBuilder: (context) {
                return mortalityReasons.keys.map((key) {
                    final isPlaceholder = key == 'Select mortality reason';
                    return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            key,
                            style: TextStyle(
                                fontSize: 14,
                                color: isPlaceholder && hasSubmitted
                                    ? errorColor
                                    : AppColors.textPrimary(context),
                                fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                        ),
                    );
                }).toList();
            },
            items: mortalityReasons.entries.map((entry) {
                    final hasInfo = entry.key != 'Select mortality reason' && entry.value.isNotEmpty;
                    return DropdownMenuItem<String>(
                        value: entry.key,
                        enabled: entry.key != 'Select mortality reason',
                        child: Row(
                            children: [
                                if (hasInfo)
                                GestureDetector(
                                    onTap: () {
                                        showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                                title: Text(entry.key),
                                                content: Text(entry.value),
                                                actions: [
                                                    TextButton(
                                                        onPressed: () => Navigator.pop(context),
                                                        child: const Text('Close'),
                                                    ),
                                                ],
                                            ),
                                        );
                                    },
                                    child: const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                                )
                                else
                                const SizedBox(width: 20),
                                const SizedBox(width: 8),
                                Flexible(
                                    child: Text(
                                        entry.key,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.textPrimary(context),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                ),
                            ],
                        ),
                    );
                }).toList(),
        );
    }
}
