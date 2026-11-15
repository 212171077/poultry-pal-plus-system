import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  computed,
  inject,
  signal,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { MatMenuModule } from '@angular/material/menu';
import { MatSnackBar } from '@angular/material/snack-bar';
import { ActivatedRoute, Router } from '@angular/router';
import { format } from 'date-fns';
import { filter, switchMap } from 'rxjs';
import { AuthService } from '../../core/auth/auth.service';
import { liveSignal } from '../../data/db/live-signal';
import { LocalExpense } from '../../data/models/local';
import {
  CoopRepository,
  ExpenseRepository,
  FarmContextRepository,
} from '../../data/repositories/repositories';
import { formatMoney } from '../../shared/format/money';
import { ConfirmDialogService } from '../../shared/ui/confirm-dialog/confirm-dialog.service';
import { CoopFilter } from '../../shared/ui/coop-filter/coop-filter';
import { KpiCard } from '../../shared/ui/kpi-card/kpi-card';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import { SyncChip } from '../../shared/ui/sync-chip/sync-chip';
import { ExpenseFormData, ExpenseFormDialog } from './expense-form-dialog/expense-form-dialog';
import { expenseIcon } from './expense-types';

interface ExpenseRow {
  readonly expense: LocalExpense;
  readonly coopName: string;
  readonly date: string;
  readonly amount: string;
  readonly icon: string;
}

@Component({
  selector: 'app-expenses-page',
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
  templateUrl: './expenses-page.html',
  styleUrl: '../../shared/records/record-list.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class ExpensesPage {
  private readonly expensesRepo = inject(ExpenseRepository);
  private readonly coopsRepo = inject(CoopRepository);
  private readonly context = inject(FarmContextRepository);
  private readonly auth = inject(AuthService);
  private readonly dialog = inject(MatDialog);
  private readonly snackBar = inject(MatSnackBar);
  private readonly confirm = inject(ConfirmDialogService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly destroyRef = inject(DestroyRef);

  private readonly allExpenses = liveSignal(() => this.expensesRepo.listRecent());
  protected readonly coopId = signal<string | null>(null);
  private readonly expenses = computed(() => {
    const coopId = this.coopId();
    const all = this.allExpenses();
    return coopId && all ? all.filter((expense) => expense.coopId === coopId) : all;
  });
  protected readonly coops = liveSignal(() => this.coopsRepo.listSorted(), []);
  private readonly settings = liveSignal(() => this.context.settings());

  protected readonly loading = computed(() => this.allExpenses() === undefined);
  protected readonly hasRecords = computed(() => (this.allExpenses()?.length ?? 0) > 0);

  protected readonly rows = computed<ExpenseRow[]>(() => {
    const names = new Map(this.coops().map((coop) => [coop.id, coop.coopName]));
    const currency = this.settings()?.currency;
    return (this.expenses() ?? []).map((expense) => ({
      expense,
      coopName: names.get(expense.coopId) ?? 'Unknown coop',
      date: format(new Date(expense.expenseDate), 'd MMM yyyy'),
      amount: formatMoney(expense.amount, currency),
      icon: expenseIcon(expense.expenseType),
    }));
  });

  protected readonly monthTotal = computed(() => {
    const month = format(new Date(), 'yyyy-MM');
    const total = (this.expenses() ?? [])
      .filter((e) => format(new Date(e.expenseDate), 'yyyy-MM') === month)
      .reduce((sum, e) => sum + e.amount, 0);
    return formatMoney(total, this.settings()?.currency);
  });

  constructor() {
    this.route.queryParamMap
      .pipe(
        filter((params) => params.get('action') === 'new'),
        takeUntilDestroyed(this.destroyRef),
      )
      .subscribe(() => {
        void this.router.navigate([], { queryParams: { action: null }, replaceUrl: true });
        void this.openForm();
      });
  }

  protected async openForm(expense?: LocalExpense): Promise<void> {
    const coops = await this.coopsRepo.listSorted();
    if (coops.length === 0) {
      const message = this.auth.canManageFarm()
        ? 'Add a coop first. Coops sync from your farm when you are online.'
        : 'No coops are assigned to you yet. Ask your farm manager to assign one.';
      this.snackBar.open(message, 'OK', { duration: 5000 });
      return;
    }
    const user = await this.context.currentUser();
    const recordedBy = user ? [user.name, user.surname].filter(Boolean).join(' ') : null;
    this.dialog
      .open<ExpenseFormDialog, ExpenseFormData, LocalExpense>(ExpenseFormDialog, {
        data: { coops, expense, recordedBy },
        autoFocus: 'first-tabbable',
        maxWidth: '95vw',
      })
      .afterClosed()
      .pipe(filter(Boolean))
      .subscribe(() =>
        this.snackBar.open(
          expense ? 'Expense updated' : 'Expense saved. It will sync automatically.',
          undefined,
          { duration: 3000 },
        ),
      );
  }

  protected remove(expense: LocalExpense): void {
    this.confirm
      .confirm({
        title: 'Delete expense?',
        message: `${expense.expenseType} on ${format(new Date(expense.expenseDate), 'd MMM yyyy')} will be removed from all devices.`,
        confirmText: 'Delete',
        destructive: true,
      })
      .pipe(
        filter(Boolean),
        switchMap(() => this.expensesRepo.remove(expense.id)),
      )
      .subscribe(() => this.snackBar.open('Expense deleted', undefined, { duration: 3000 }));
  }
}
