import { FarmData } from '../analytics/farm-metrics';

export interface ActivityItem {
  readonly id: string;
  readonly icon: string;
  readonly title: string;
  readonly coopId: string;
  readonly date: string;
  readonly path: string;
}

/** The most recent records across sales, expenses, losses and eggs, newest first. */
export function recentActivity(data: FarmData, limit = 8): ActivityItem[] {
  const items: ActivityItem[] = [
    ...data.sales.map((r) => ({
      id: r.id,
      icon: 'payments',
      title: `Sale${r.additionalInfo ? ` · ${r.additionalInfo}` : ''}`,
      coopId: r.coopId,
      date: r.saleDate,
      path: '/sales',
    })),
    ...data.expenses.map((r) => ({
      id: r.id,
      icon: 'receipt_long',
      title: `Expense · ${r.expenseType}`,
      coopId: r.coopId,
      date: r.expenseDate,
      path: '/expenses',
    })),
    ...data.mortalities.map((r) => ({
      id: r.id,
      icon: 'monitor_heart',
      title: `${r.numberOfDeaths} lost · ${r.reason}`,
      coopId: r.coopId,
      date: r.dateOccurred,
      path: '/mortality',
    })),
    ...data.eggRecords.map((r) => ({
      id: r.id,
      icon: 'egg',
      title: `${r.totalEggs ?? 0} eggs packaged`,
      coopId: r.coopId,
      date: r.createdDate,
      path: '/eggs',
    })),
  ];
  return items
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
    .slice(0, limit);
}
