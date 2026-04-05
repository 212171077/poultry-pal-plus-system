import 'package:flutter/material.dart';
import 'package:poultry_pal_plus_app/theme/app_theme.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class ExpenseTypeDropdown extends StatelessWidget {
    final String value;
    final void Function(String?) onChanged;
    final bool showErrorOnlyAfterSubmit;

    const ExpenseTypeDropdown({
        super.key,
        required this.value,
        required this.onChanged,
        required this.showErrorOnlyAfterSubmit,
    });

    @override
    Widget build(BuildContext context) {
        final expenseTypes = {
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

        final isInvalid = value == 'Select expense type' && showErrorOnlyAfterSubmit;

        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: value,
                    onChanged: (val) {
                        if (val != 'Select expense type') {
                            onChanged(val);
                        }
                    },
                    decoration: InputDecoration(
                        labelText: 'Expense Type',
                        labelStyle: const TextStyle(fontSize: 14),
                        prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(Icons.category_outlined, color: AppColors.adaptivePrimary(context)),
                        ),
                        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.adaptivePrimary(context).withAlpha(128)),
                        ),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.adaptivePrimary(context).withAlpha(128)),
                        ),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.adaptivePrimary(context), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.error),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppColors.error, width: 2),
                        ),
                      errorText: isInvalid ? 'Please select an expense type' : null,
                    ),
                    dropdownStyleData: DropdownStyleData(
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).cardColor,
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
                        return expenseTypes.keys.map((key) {
                                return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                        key,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: isInvalid ? AppColors.error : Colors.black,
                                            fontWeight: FontWeight.w400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                );
                            }).toList();
                    },
                    items: expenseTypes.entries.map((entry) {
                            final hasInfo = entry.key != 'Select expense type' && entry.value.isNotEmpty;
                            return DropdownMenuItem<String>(
                                value: entry.key,
                                enabled: entry.key != 'Select expense type',
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
                ),
            ],
        );
    }
}
