/** Choices offered by the record forms; the values match what the mobile app sends. */

export const MORTALITY_REASONS: readonly string[] = [
  'Diseases',
  'Poor Nutrition',
  'Environmental Stress',
  'Parasites',
  'Poor Hygiene & Sanitation',
  'Genetic Factors',
  'Poor Handling & Transportation',
  'Predators',
  'Cannibalism and Pecking',
  'Water & Feed Issues',
  'Sudden Death Syndrome',
  'Overcrowding',
  'Toxins & Poisoning',
];

export const EGG_SIZES: readonly string[] = [
  'Peewee',
  'Small',
  'Medium',
  'Large',
  'Extra-Large',
  'Jumbo',
  'Mix Size',
];

export const DEFAULT_EGG_SIZE = 'Large';

/** Box sizes as the backend accepts them (`EggBoxSizes.java`, case-insensitive). */
export const BOX_SIZES: readonly { readonly value: string; readonly eggs: number }[] = [
  { value: '6 Eggs Box', eggs: 6 },
  { value: '12 Eggs Box', eggs: 12 },
  { value: '18 Eggs Box', eggs: 18 },
  { value: '30 Eggs Box', eggs: 30 },
  { value: '60 Eggs Box', eggs: 60 },
];

/** Egg sizes sold to buyers. */
export const SALE_EGG_SIZES: readonly string[] = ['Large', 'Small'];

/** How eggs are sold; the codes match the backend `EggSalePackaging` enum. */
export const SALE_PACKAGING: readonly {
  readonly value: string;
  readonly label: string;
  readonly unit: string;
  readonly eggs: number;
}[] = [
  { value: 'TRAY_60', label: 'Tray of 60 eggs', unit: 'tray', eggs: 60 },
  { value: 'TRAY_30', label: 'Tray of 30 eggs', unit: 'tray', eggs: 30 },
  { value: 'BOX_360', label: 'Box (60 eggs × 6)', unit: 'box', eggs: 360 },
  { value: 'SINGLE', label: 'Single eggs', unit: 'egg', eggs: 1 },
];

export const DEFAULT_BOX_SIZE = '30 Eggs Box';
