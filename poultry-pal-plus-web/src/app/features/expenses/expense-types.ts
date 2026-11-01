export interface ExpenseType {
  readonly name: string;
  readonly icon: string;
}

/** Same categories as the mobile app (`expense_type_dropdown.dart`), so reports line up. */
export const EXPENSE_TYPES: readonly ExpenseType[] = [
  { name: 'Feed Costs', icon: 'grass' },
  { name: 'Chicks or Hatching Eggs', icon: 'egg' },
  { name: 'Housing and Coop Maintenance', icon: 'home_repair_service' },
  { name: 'Vaccination and Medications', icon: 'vaccines' },
  { name: 'Heating, Cooling, and Ventilation', icon: 'thermostat' },
  { name: 'Water Supply and Equipment', icon: 'water_drop' },
  { name: 'Labor Costs', icon: 'engineering' },
  { name: 'Electricity and Utilities', icon: 'bolt' },
  { name: 'Transportation and Delivery', icon: 'local_shipping' },
  { name: 'Cleaning and Biosecurity Supplies', icon: 'sanitizer' },
  { name: 'Insurance and Licensing', icon: 'verified_user' },
  { name: 'Bedding and Nesting Material', icon: 'bed' },
  { name: 'Breeding Costs', icon: 'family_restroom' },
  { name: 'Marketing and Sales Expenses', icon: 'campaign' },
  { name: 'Equipment and Tools', icon: 'construction' },
  { name: 'Waste Disposal', icon: 'delete' },
  { name: 'Record-Keeping and Software', icon: 'computer' },
  { name: 'Miscellaneous Supplies', icon: 'category' },
];

export function expenseIcon(type: string): string {
  return EXPENSE_TYPES.find((t) => t.name === type)?.icon ?? 'receipt_long';
}
