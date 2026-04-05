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
            decoration: InputDecoration(
                labelText: 'Mortality Reason',
                labelStyle: const TextStyle(fontSize: 14),
                prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 0), // tighter spacing
                    child: Icon(Icons.category_outlined, color: AppColors.adaptivePrimary(context)),
                ),
                prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // reduced horizontal padding
                border: border,
                enabledBorder: border,
                focusedBorder: focusedBorder,
                errorBorder: border.copyWith(
                    borderSide: const BorderSide(color: AppColors.error),
                ),
                focusedErrorBorder: border.copyWith(
                    borderSide: const BorderSide(color: AppColors.error, width: 2),
                ),
            ),
            dropdownStyleData: DropdownStyleData(
                decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.adaptivePrimary(context).withAlpha(80)),
                    boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                        ),
                    ],
                ),
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
                    color: isPlaceholder && hasSubmitted ? AppColors.error : Colors.black,
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
