import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { format } from 'date-fns';
import { filter } from 'rxjs';
import { liveSignal } from '../../data/db/live-signal';
import { LocalSale } from '../../data/models/local';
import { SALE_PACKAGING } from '../../data/models/record-options';
import { SaleRepository } from '../../data/repositories/repositories';
import { formatMoney } from '../../shared/format/money';
import { RecordListPage } from '../../shared/records/record-page';
import { CoopFilter } from '../../shared/ui/coop-filter/coop-filter';
import { KpiCard } from '../../shared/ui/kpi-card/kpi-card';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { SyncChip } from '../../shared/ui/sync-chip/sync-chip';
import { SaleFormData, SaleFormDialog } from './sale-form-dialog/sale-form-dialog';

interface SaleRow {
  readonly sale: LocalSale;
  readonly title: string;
  readonly meta: string;
  readonly detail: string;
  readonly total: string;
  readonly icon: string;
  readonly pending: boolean;
}

@Component({
  selector: 'app-sales-page',
  imports: [
    PageHeader,
    EmptyState,
    SyncChip,
    CoopFilter,
    KpiCard,
    MatButtonModule,
    MatIconModule,
    MatMenuModule,
  ],
  templateUrl: './sales-page.html',
  styleUrl: '../../shared/records/record-list.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class SalesPage extends RecordListPage<LocalSale> {
  private readonly salesRepo = inject(SaleRepository);
  private readonly allSales = liveSignal(() => this.salesRepo.listRecent());
  protected readonly coopId = signal<string | null>(null);
  private readonly sales = computed(() => {
    const coopId = this.coopId();
    const all = this.allSales();
    return coopId && all ? all.filter((sale) => sale.coopId === coopId) : all;
  });

  protected readonly loading = computed(() => this.allSales() === undefined);
  protected readonly hasRecords = computed(() => (this.allSales()?.length ?? 0) > 0);

  protected readonly rows = computed<SaleRow[]>(() => {
    const names = new Map(this.coops().map((coop) => [coop.id, coop.coopName]));
    const currency = this.settings()?.currency;
    const money = (value: number | null | undefined) => formatMoney(value ?? 0, currency);
    return (this.sales() ?? []).map((sale) => {
      const packaging = SALE_PACKAGING.find((p) => p.value === sale.eggPackaging);
      const eggs = !!packaging || !!sale.numberOfDozensSold;
      return {
        sale,
        title: sale.additionalInfo || 'Sale',
        meta: `${names.get(sale.coopId) ?? 'Unknown coop'} · ${format(new Date(sale.saleDate), 'd MMM yyyy')}`,
        detail: packaging
          ? `${sale.quantitySold ?? 0} × ${packaging.label}${sale.eggSize ? ` (${sale.eggSize})` : ''} @ ${money(sale.pricePerUnit)}`
          : eggs
            ? `${sale.numberOfDozensSold} dozen eggs × ${money(sale.salePricePerDozen)}`
            : `${sale.numberOfChickensSold ?? 0} chickens × ${money(sale.salePricePerChicken)}`,
        total: money(sale.totalSaleAmount),
        icon: eggs ? 'egg' : 'savings',
        pending: sale.paymentStatus === 'PENDING',
      };
    });
  });

  protected readonly summary = computed(() => {
    const month = format(new Date(), 'yyyy-MM');
    const sales = this.sales() ?? [];
    const sum = (list: readonly LocalSale[]) =>
      list.reduce((total, sale) => total + (sale.totalSaleAmount ?? 0), 0);
    const currency = this.settings()?.currency;
    return {
      month: formatMoney(
        sum(sales.filter((s) => format(new Date(s.saleDate), 'yyyy-MM') === month)),
        currency,
      ),
      unpaid: formatMoney(sum(sales.filter((s) => s.paymentStatus === 'PENDING')), currency),
    };
  });

  protected async openForm(sale?: LocalSale, coopId?: string | null): Promise<void> {
    const context = await this.formContext(coopId);
    if (!context) return;
    this.dialog
      .open<SaleFormDialog, SaleFormData, LocalSale>(SaleFormDialog, {
        data: { ...context, sale, currency: this.settings()?.currency },
        autoFocus: 'first-tabbable',
        maxWidth: '95vw',
      })
      .afterClosed()
      .pipe(filter(Boolean))
      .subscribe(() =>
        this.saved(sale ? 'Sale updated' : 'Sale saved. It will sync automatically.'),
      );
  }

  protected async markPaid(sale: LocalSale): Promise<void> {
    await this.salesRepo.update(sale.id, { paymentStatus: 'PAID' });
    this.saved('Marked as paid');
  }

  protected remove(sale: LocalSale): void {
    this.confirmDelete(
      'Delete sale?',
      `The sale${sale.additionalInfo ? ` (${sale.additionalInfo})` : ''} on ${format(new Date(sale.saleDate), 'd MMM yyyy')} will be removed from all devices.`,
      () => this.salesRepo.remove(sale.id),
      'Sale deleted',
    );
  }
}
