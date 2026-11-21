import { ChangeDetectionStrategy, Component, computed, inject, signal } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { Toast } from '../../shared/ui/toast/toast.service';
import { ProductionRepository } from '../../data/repositories/production-repository';
import { DateField } from '../../shared/ui/date-field/date-field';
import { OfflineDataNote } from '../../shared/ui/offline-data-note/offline-data-note';
import { EmptyState } from '../../shared/ui/empty-state/empty-state';
import { PageHeader } from '../../shared/ui/page-header/page-header';
import {
  BirdPlacement,
  HatcherCycle,
  HouseOccupancy,
  MovementType,
  PlacementSource,
} from './production-api';
import { describeError } from './production-settings-page';

export const MOVEMENT_LABELS: Record<MovementType, string> = {
  MORTALITY: 'Mortality',
  SALE: 'Sale',
  TRANSFER: 'Transfer out',
  OTHER_REMOVAL: 'Other removal',
  CORRECTION: 'Correction',
};

export function todayIso(): string {
  const now = new Date();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');
  return `${now.getFullYear()}-${month}-${day}`;
}

export function occupancyPercent(house: Pick<HouseOccupancy, 'capacity' | 'occupied'>): number {
  return house.capacity > 0
    ? Math.min(100, Math.round((house.occupied / house.capacity) * 100))
    : 0;
}

@Component({
  selector: 'app-placements-page',
  imports: [
    OfflineDataNote,
    PageHeader,
    EmptyState,
    DateField,
    MatButtonModule,
    MatFormFieldModule,
    MatInputModule,
  ],
  templateUrl: './placements-page.html',
  styleUrl: './placements-page.scss',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export default class PlacementsPage {
  protected readonly repo = inject(ProductionRepository);
  private readonly snackBar = inject(Toast);
  protected readonly houses = signal<readonly HouseOccupancy[]>([]);
  protected readonly placements = signal<readonly BirdPlacement[]>([]);
  protected readonly cycles = signal<readonly HatcherCycle[]>([]);
  protected readonly error = signal<string | null>(null);
  protected readonly busy = signal(false);
  protected readonly source = signal<PlacementSource>('PURCHASED_DAY_OLD');
  protected readonly houseNames = computed(
    () => new Map(this.houses().map((house) => [house.houseId, house.name])),
  );
  protected readonly movementTypes = Object.entries(MOVEMENT_LABELS) as [MovementType, string][];
  protected readonly percent = occupancyPercent;
  protected readonly today = todayIso();
  protected readonly houseId = signal('');
  protected readonly customQuantity = signal<string | null>(null);
  protected readonly placementDate = signal(todayIso());
  protected readonly movementDate = signal(todayIso());
  protected readonly movementType = signal('MORTALITY');
  protected readonly increase = signal(false);
  protected readonly cycleId = signal('');
  protected readonly supplier = signal('');
  protected readonly age = signal('0');
  protected readonly freeSpace = computed(
    () => this.houses().find((h) => h.houseId === this.houseId())?.available ?? 0,
  );
  protected readonly quantity = computed(
    () => this.customQuantity() ?? String(this.freeSpace() || ''),
  );
  protected readonly defaultCycleId = computed(() => this.cycles().at(-1)?.id ?? '');

  constructor() {
    void this.load();
  }

  protected setHouse(id: string): void {
    this.houseId.set(id);
    this.customQuantity.set(null);
  }

  protected setSource(value: string): void {
    this.source.set(value === 'OWN_HATCH' ? 'OWN_HATCH' : 'PURCHASED_DAY_OLD');
  }

  protected place(
    houseId: string,
    quantity: string,
    date: string,
    cycleId: string,
    supplier: string,
    age: string,
  ): Promise<void> {
    const count = Number(quantity);
    if (!houseId || !Number.isInteger(count) || count < 1 || !date) {
      this.error.set('Choose a house, a whole number of chicks and a placement date.');
      return Promise.resolve();
    }
    const own = this.source() === 'OWN_HATCH';
    if (own && !cycleId) {
      this.error.set('Choose the hatcher cycle these chicks came from.');
      return Promise.resolve();
    }
    return this.run(async () => {
      const placed = await this.repo.placeChicks({
        source: this.source(),
        sourceCycleId: own ? cycleId : undefined,
        sourceReference: !own && supplier ? supplier : undefined,
        houseId,
        quantity: count,
        placementDate: date,
        ageDaysAtArrival: !own && age !== '' ? Number(age) : undefined,
      });
      this.snackBar.open(
        placed ? 'Chicks placed.' : 'Saved on this device. It will sync when you are online.',
        'OK',
      );
    }, 'Could not place these chicks.');
  }

  protected record(
    placementId: string,
    type: string,
    count: string,
    date: string,
    reason: string,
    increase: boolean,
  ): Promise<void> {
    const n = Number(count);
    if (!Number.isInteger(n) || n < 1 || !date) {
      this.error.set('Enter a whole number of birds and a date.');
      return Promise.resolve();
    }
    const kind = type as MovementType;
    return this.run(async () => {
      const moved = await this.repo.addMovement(placementId, {
        type: kind,
        count: n,
        date,
        reason: reason || undefined,
        increase: kind === 'CORRECTION' ? increase : undefined,
      });
      this.snackBar.open(
        moved ? 'Movement recorded.' : 'Saved on this device. It will sync when you are online.',
        'OK',
      );
    }, 'Could not record this movement.');
  }

  private async run(action: () => Promise<void>, fallback: string): Promise<void> {
    this.error.set(null);
    this.busy.set(true);
    try {
      await action();
      await this.load();
    } catch (error) {
      this.error.set(describeError(error, fallback));
    } finally {
      this.busy.set(false);
    }
  }

  private async load(): Promise<void> {
    try {
      const [houses, placements, batches] = await Promise.all([
        this.repo.occupancy(),
        this.repo.placements(),
        this.repo.batches(),
      ]);
      this.houses.set(houses);
      const current = houses.find((h) => h.houseId === this.houseId());
      if (!current) {
        this.houseId.set(
          (houses.find((h) => h.enabled && h.available > 0) ?? houses[0])?.houseId ?? '',
        );
      }
      this.customQuantity.set(null);
      this.placements.set(placements);
      this.cycles.set(
        batches
          .flatMap((batch) => batch.hatcherCycles)
          .filter((cycle) => cycle.status === 'COMPLETED'),
      );
    } catch (error) {
      this.error.set(describeError(error, 'Could not load chicken houses.'));
    }
  }
}
