import { format } from 'date-fns';
import { ExportTable } from '../../shared/export/table-export';
import { CoopSummary, DateRange, FarmData } from '../analytics/farm-metrics';

const day = (value: string) => format(new Date(value), 'yyyy-MM-dd');
const inRange = (value: string, range: DateRange) => {
  const time = new Date(value).getTime();
  return time >= range.from.getTime() && time <= range.to.getTime();
};

/** Tables for CSV/Excel export: a coop summary plus the detailed records inside `range`. */
export function reportTables(
  data: FarmData,
  coops: readonly CoopSummary[],
  range: DateRange,
): ExportTable[] {
  const names = new Map(data.coops.map((coop) => [coop.id, coop.coopName]));
  const coopName = (id: string) => names.get(id) ?? 'Unknown coop';
  const round = (value: number) => Math.round(value * 100) / 100;
  return [
    {
      name: 'Coop summary',
      headers: [
        'Coop',
        'Type',
        'Live birds',
        'Sales',
        'Expenses',
        'Profit',
        'Eggs',
        'Deaths',
        'Mortality rate %',
      ],
      rows: coops.map((c) => [
        c.coopName,
        c.coopType,
        c.liveBirds,
        round(c.sales),
        round(c.expenses),
        round(c.profit),
        c.eggs,
        c.deaths,
        round(c.mortalityRate),
      ]),
    },
    {
      name: 'Sales',
      headers: [
        'Date',
        'Coop',
        'Additional info',
        'Egg size',
        'Packaging',
        'Quantity',
        'Price per unit',
        'Dozens',
        'Price per dozen',
        'Chickens',
        'Price per chicken',
        'Total',
        'Payment',
      ],
      rows: data.sales
        .filter((r) => inRange(r.saleDate, range))
        .sort((a, b) => a.saleDate.localeCompare(b.saleDate))
        .map((r) => [
          day(r.saleDate),
          coopName(r.coopId),
          r.additionalInfo,
          r.eggSize,
          r.eggPackaging,
          r.quantitySold,
          r.pricePerUnit,
          r.numberOfDozensSold,
          r.salePricePerDozen,
          r.numberOfChickensSold,
          r.salePricePerChicken,
          r.totalSaleAmount,
          r.paymentStatus,
        ]),
    },
    {
      name: 'Expenses',
      headers: ['Date', 'Coop', 'Type', 'Amount', 'Notes'],
      rows: data.expenses
        .filter((r) => inRange(r.expenseDate, range))
        .sort((a, b) => a.expenseDate.localeCompare(b.expenseDate))
        .map((r) => [
          day(r.expenseDate),
          coopName(r.coopId),
          r.expenseType,
          r.amount,
          r.additionalInfo,
        ]),
    },
    {
      name: 'Mortality',
      headers: ['Date', 'Coop', 'Deaths', 'Reason'],
      rows: data.mortalities
        .filter((r) => inRange(r.dateOccurred, range))
        .sort((a, b) => a.dateOccurred.localeCompare(b.dateOccurred))
        .map((r) => [day(r.dateOccurred), coopName(r.coopId), r.numberOfDeaths, r.reason]),
    },
    {
      name: 'Egg production',
      headers: ['Date', 'Coop', 'Egg size', 'Box size', 'Boxes', 'Total eggs'],
      rows: data.eggRecords
        .filter((r) => inRange(r.createdDate, range))
        .sort((a, b) => a.createdDate.localeCompare(b.createdDate))
        .map((r) => [
          day(r.createdDate),
          coopName(r.coopId),
          r.eggSize,
          r.boxSize,
          r.numberOfBoxes,
          r.totalEggs,
        ]),
    },
  ];
}
