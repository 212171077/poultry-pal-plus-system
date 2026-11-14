import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable, firstValueFrom } from 'rxjs';
import { APP_CONFIG } from '../../core/config/app-config';
import { ApiError, unwrapApi } from '../../core/http/api-error';
import { ApiResponse } from '../../core/http/api-response';

export type EquipmentType = 'INCUBATOR' | 'HATCHER' | 'CHICKEN_HOUSE';

export interface ProductionSettings {
  readonly id: string;
  readonly timeZone: string;
  readonly incubationDays: number;
  readonly transferDay: number;
  readonly broodingDays: number;
  readonly expectedHatchRate: number;
  readonly expectedMortalityRate: number;
  readonly defaultGrowOutDays: number;
  readonly supplierLeadTimeDays: number | null;
  readonly estimatesOnly: boolean;
  readonly reminderRules: readonly ReminderRule[];
  readonly version: number;
}

export type ReminderTaskType =
  'TRANSFER' | 'BROODER_PREPARATION' | 'PACKAGING' | 'VACCINATION' | 'CUSTOM';
export type ReminderAnchor = 'BATCH_START' | 'BATCH_TRANSFER' | 'BATCH_HATCH';
export type ReminderStatus = 'OPEN' | 'COMPLETED' | 'CANCELLED';

export interface ReminderRule {
  readonly key?: string;
  readonly taskType: ReminderTaskType;
  readonly anchor: ReminderAnchor;
  readonly offsetDays: number;
  readonly title: string;
  readonly enabled: boolean;
}

export interface ProductionReminder {
  readonly id: string;
  readonly sourceReference: string | null;
  readonly taskType: ReminderTaskType;
  readonly title: string;
  readonly dueDate: string;
  readonly status: ReminderStatus;
  readonly overdue: boolean;
  readonly completedBy: string | null;
  readonly version: number;
}

/** reminderRules is optional: omitting it keeps the farm's current rules. */
export type ProductionSettingsInput = Omit<
  ProductionSettings,
  'id' | 'estimatesOnly' | 'reminderRules'
> & { readonly reminderRules?: readonly ReminderRule[] };

export interface ProductionEquipment {
  readonly id: string;
  readonly type: EquipmentType;
  readonly name: string;
  readonly capacity: number;
  readonly enabled: boolean;
  readonly hatcherOccupancyDays: number | null;
  readonly notes: string | null;
  readonly version: number;
}

export interface ProductionEquipmentInput {
  readonly type?: EquipmentType;
  readonly name: string;
  readonly capacity: number;
  readonly enabled: boolean;
  readonly hatcherOccupancyDays?: number | null;
  readonly notes?: string | null;
  readonly version?: number;
}

export type BatchStatus = 'PLANNED' | 'INCUBATING' | 'TRANSFERRED' | 'COMPLETED' | 'CANCELLED';
export type CycleStatus = 'RESERVED' | 'IN_HATCHER' | 'COMPLETED' | 'CANCELLED';

export interface HatcherCycle {
  readonly id: string;
  readonly incubationBatchId: string;
  readonly hatcherId: string;
  readonly reference: string;
  readonly quantity: number;
  readonly plannedTransferDate: string;
  readonly actualTransferDate: string | null;
  readonly expectedHatchDate: string;
  readonly status: CycleStatus;
  readonly version: number;
}

export interface IncubationBatch {
  readonly id: string;
  readonly reference: string;
  readonly equipmentId: string;
  readonly eggsSet: number;
  readonly eggsReserved: number;
  readonly eggsUnassigned: number;
  readonly plannedStartDate: string;
  readonly plannedTransferDate: string;
  readonly plannedHatchDate: string;
  readonly actualStartDate: string | null;
  readonly status: BatchStatus;
  readonly eggSource: string | null;
  readonly notes: string | null;
  readonly hatcherCycles: readonly HatcherCycle[];
  readonly version: number;
}

export interface IncubationBatchInput {
  readonly reference?: string;
  readonly equipmentId: string;
  readonly eggsSet: number;
  readonly plannedStartDate: string;
  readonly eggSource?: string;
  readonly notes?: string;
}

export interface OutcomeCount {
  readonly category: string;
  readonly count: number;
}

export interface HatchResult {
  readonly id: string;
  readonly hatcherCycleId: string;
  readonly incubationBatchId: string;
  readonly batchReference: string;
  readonly cycleReference: string;
  readonly eggsTransferred: number;
  readonly hatchedChicks: number;
  readonly unhatchedEggs: number;
  readonly weakChicks: number;
  readonly otherOutcomes: readonly OutcomeCount[];
  readonly resultDate: string;
  /** Percentage, or null when no eggs were transferred. */
  readonly hatchRate: number | null;
  readonly notes: string | null;
  readonly revisionCount: number;
  readonly version: number;
}

export interface HatchResultInput {
  readonly hatchedChicks: number;
  readonly unhatchedEggs: number;
  readonly weakChicks?: number;
  readonly otherOutcomes?: readonly OutcomeCount[];
  readonly resultDate: string;
  readonly notes?: string;
  readonly version?: number;
}

export interface HatchingReport {
  readonly summary: {
    readonly results: number;
    readonly eggsTransferred: number;
    readonly hatchedChicks: number;
    readonly unhatchedEggs: number;
    readonly weakChicks: number;
    readonly hatchRate: number | null;
    readonly weakRate: number | null;
  };
  readonly trend: readonly {
    readonly period: string;
    readonly results: number;
    readonly eggsTransferred: number;
    readonly hatchedChicks: number;
    readonly hatchRate: number | null;
  }[];
  readonly rows: readonly HatchResult[];
  readonly page: number;
  readonly size: number;
  readonly totalElements: number;
}

export interface HatchingReportFilter {
  readonly from?: string;
  readonly to?: string;
}

export type PlacementSource = 'OWN_HATCH' | 'PURCHASED_DAY_OLD';
export type MovementType = 'MORTALITY' | 'SALE' | 'TRANSFER' | 'OTHER_REMOVAL' | 'CORRECTION';

export interface BirdMovement {
  readonly id: string;
  readonly placementId: string;
  readonly type: MovementType;
  readonly count: number;
  readonly increase: boolean;
  readonly date: string;
  readonly reason: string | null;
  readonly relatedRecordType: string | null;
  readonly relatedRecordId: string | null;
}

export interface BirdPlacement {
  readonly id: string;
  readonly reference: string;
  readonly source: PlacementSource;
  readonly sourceCycleId: string | null;
  readonly sourceReference: string | null;
  readonly houseId: string;
  readonly quantity: number;
  readonly arrivalDate: string | null;
  readonly placementDate: string;
  readonly ageDaysAtArrival: number;
  readonly notes: string | null;
  readonly remaining: number;
  readonly mortality: number;
  readonly sold: number;
  readonly otherRemovals: number;
  readonly status: 'ACTIVE' | 'CLOSED';
  readonly movements: readonly BirdMovement[] | null;
  readonly version: number;
}

export interface BirdPlacementInput {
  readonly source: PlacementSource;
  readonly sourceCycleId?: string;
  readonly sourceReference?: string;
  readonly houseId: string;
  readonly quantity: number;
  readonly arrivalDate?: string;
  readonly placementDate: string;
  readonly ageDaysAtArrival?: number;
  readonly notes?: string;
}

export interface BirdMovementInput {
  readonly type: MovementType;
  readonly count: number;
  readonly increase?: boolean;
  readonly date: string;
  readonly reason?: string;
}

export interface HouseOccupancy {
  readonly houseId: string;
  readonly name: string;
  readonly enabled: boolean;
  readonly capacity: number;
  readonly occupied: number;
  readonly available: number;
}

export type SourceMethod = 'INCUBATE_EGGS' | 'PURCHASE_DAY_OLD_CHICKS';
export type PlanStatus = 'DRAFT' | 'COMMITTED' | 'NEEDS_REVIEW' | 'COMPLETED' | 'CANCELLED';

export interface PlanInput {
  readonly sourceMethod: SourceMethod;
  readonly targetReadyDate: string;
  readonly targetQuantity: number;
  readonly targetAgeDays?: number;
  readonly name?: string;
  readonly notes?: string;
}

export interface PlanCalculation {
  readonly sourceMethod: SourceMethod;
  readonly targetReadyDate: string;
  readonly targetQuantity: number;
  readonly targetAgeDays: number;
  readonly housePlacementDate: string;
  readonly hatchOrArrivalDate: string;
  readonly incubationStartDate: string | null;
  readonly transferDate: string | null;
  readonly latestOrderDate: string | null;
  readonly eggsRequired: number | null;
  readonly chicksRequired: number;
  readonly feasible: boolean;
  readonly constraints: readonly string[];
  readonly assumptions: readonly string[];
  readonly calculatedAt: string;
}

export interface ProductionPlan {
  readonly id: string;
  readonly name: string | null;
  readonly notes: string | null;
  readonly status: PlanStatus;
  readonly calculation: PlanCalculation;
  readonly recalculation: PlanCalculation | null;
  readonly decisionReason: string | null;
  readonly version: number;
}

export interface ScheduleSearchInput {
  readonly eggs: number;
  readonly earliestStart: string;
  readonly latestStart: string;
  readonly incubatorId?: string;
  readonly hatcherId?: string;
  readonly houseId?: string;
}

export interface ScheduleCandidate {
  readonly start: string;
  readonly transferDate: string;
  readonly hatchDate: string;
  readonly houseArrivalDate: string;
  readonly feasible: boolean;
  readonly reasons: readonly string[];
}

export interface ScheduleOptions {
  readonly eggs: number;
  readonly expectedChicks: number;
  readonly recommendedStart: string | null;
  readonly windows: readonly { readonly from: string; readonly to: string }[];
  readonly candidates: readonly ScheduleCandidate[];
  readonly explanation: string;
  readonly assumptions: readonly string[];
  readonly calculatedAt: string;
}

/** Mirrors the backend `ProductionSnapshotResponse`. */
export interface ProductionSnapshot {
  readonly generatedAt: string;
  readonly settings: ProductionSettings;
  readonly equipment: readonly ProductionEquipment[];
  readonly batches: readonly IncubationBatch[];
  readonly reminders: readonly ProductionReminder[];
  readonly placements: readonly BirdPlacement[];
  readonly occupancy: readonly HouseOccupancy[];
  readonly plans: readonly ProductionPlan[];
}

export type SnapshotSection = Exclude<keyof ProductionSnapshot, 'generatedAt'>;

@Injectable({ providedIn: 'root' })
export class ProductionApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1/production`;

  settings(): Promise<ProductionSettings> {
    return this.unwrap(this.http.get<ApiResponse<ProductionSettings>>(`${this.baseUrl}/settings`));
  }

  updateSettings(input: ProductionSettingsInput): Promise<ProductionSettings> {
    return this.unwrap(
      this.http.put<ApiResponse<ProductionSettings>>(`${this.baseUrl}/settings`, input),
    );
  }

  equipment(): Promise<ProductionEquipment[]> {
    return this.unwrap(
      this.http.get<ApiResponse<ProductionEquipment[]>>(`${this.baseUrl}/equipment`),
    );
  }

  createEquipment(input: ProductionEquipmentInput): Promise<ProductionEquipment> {
    return this.unwrap(
      this.http.post<ApiResponse<ProductionEquipment>>(`${this.baseUrl}/equipment`, input),
    );
  }

  updateEquipment(id: string, input: ProductionEquipmentInput): Promise<ProductionEquipment> {
    return this.unwrap(
      this.http.put<ApiResponse<ProductionEquipment>>(
        `${this.baseUrl}/equipment/${encodeURIComponent(id)}`,
        input,
      ),
    );
  }

  archiveEquipment(id: string): Promise<void> {
    return this.unwrap(
      this.http.delete<ApiResponse<void>>(`${this.baseUrl}/equipment/${encodeURIComponent(id)}`),
      false,
    );
  }

  batches(status?: BatchStatus): Promise<IncubationBatch[]> {
    const query = status ? `?status=${status}` : '';
    return this.unwrap(
      this.http.get<ApiResponse<IncubationBatch[]>>(`${this.baseUrl}/batches${query}`),
    );
  }

  createBatch(input: IncubationBatchInput): Promise<IncubationBatch> {
    return this.unwrap(
      this.http.post<ApiResponse<IncubationBatch>>(`${this.baseUrl}/batches`, input),
    );
  }

  startBatch(id: string, actualDate?: string): Promise<IncubationBatch> {
    return this.command(`/batches/${enc(id)}/start`, actualDate ? { actualDate } : {});
  }

  cancelBatch(id: string, reason?: string): Promise<IncubationBatch> {
    return this.command(`/batches/${enc(id)}/cancel`, reason ? { reason } : {});
  }

  reserveCycle(batchId: string, hatcherId: string, quantity: number): Promise<IncubationBatch> {
    return this.command(`/batches/${enc(batchId)}/hatcher-cycles`, { hatcherId, quantity });
  }

  transferCycle(cycleId: string, actualDate?: string): Promise<IncubationBatch> {
    return this.command(
      `/hatcher-cycles/${enc(cycleId)}/transfer`,
      actualDate ? { actualDate } : {},
    );
  }

  cancelCycle(cycleId: string): Promise<IncubationBatch> {
    return this.command(`/hatcher-cycles/${enc(cycleId)}/cancel`, {});
  }

  reminders(status: ReminderStatus = 'OPEN'): Promise<ProductionReminder[]> {
    return this.unwrap(
      this.http.get<ApiResponse<ProductionReminder[]>>(
        `${this.baseUrl}/reminders?status=${status}`,
      ),
    );
  }

  completeReminder(id: string): Promise<ProductionReminder> {
    return this.unwrap(
      this.http.post<ApiResponse<ProductionReminder>>(
        `${this.baseUrl}/reminders/${enc(id)}/complete`,
        {},
      ),
    );
  }

  recordResult(cycleId: string, input: HatchResultInput): Promise<HatchResult> {
    return this.unwrap(
      this.http.post<ApiResponse<HatchResult>>(
        `${this.baseUrl}/hatcher-cycles/${enc(cycleId)}/results`,
        input,
      ),
    );
  }

  hatchingReport(filter: HatchingReportFilter = {}): Promise<HatchingReport> {
    return this.unwrap(
      this.http.get<ApiResponse<HatchingReport>>(
        `${this.baseUrl}/reports/hatching${reportQuery(filter)}`,
      ),
    );
  }

  hatchingCsv(filter: HatchingReportFilter = {}): Promise<Blob> {
    return firstValueFrom(
      this.http.get(`${this.baseUrl}/reports/hatching.csv${reportQuery(filter)}`, {
        responseType: 'blob',
      }),
    );
  }

  placements(activeOnly = false, houseId?: string): Promise<BirdPlacement[]> {
    const params = new URLSearchParams();
    if (activeOnly) params.set('activeOnly', 'true');
    if (houseId) params.set('houseId', houseId);
    const query = params.toString();
    return this.unwrap(
      this.http.get<ApiResponse<BirdPlacement[]>>(
        `${this.baseUrl}/placements${query ? `?${query}` : ''}`,
      ),
    );
  }

  placement(id: string): Promise<BirdPlacement> {
    return this.unwrap(
      this.http.get<ApiResponse<BirdPlacement>>(`${this.baseUrl}/placements/${enc(id)}`),
    );
  }

  placeChicks(input: BirdPlacementInput): Promise<BirdPlacement> {
    return this.unwrap(
      this.http.post<ApiResponse<BirdPlacement>>(`${this.baseUrl}/placements`, input),
    );
  }

  addMovement(
    placementId: string,
    input: BirdMovementInput,
    idempotencyKey: string = crypto.randomUUID(),
  ): Promise<BirdMovement> {
    return this.unwrap(
      this.http.post<ApiResponse<BirdMovement>>(
        `${this.baseUrl}/placements/${enc(placementId)}/movements`,
        input,
        { headers: { 'Idempotency-Key': idempotencyKey } },
      ),
    );
  }

  calculatePlan(input: PlanInput): Promise<PlanCalculation> {
    return this.unwrap(
      this.http.post<ApiResponse<PlanCalculation>>(`${this.baseUrl}/plans/calculate`, input),
    );
  }

  plans(openOnly = false): Promise<ProductionPlan[]> {
    return this.unwrap(
      this.http.get<ApiResponse<ProductionPlan[]>>(
        `${this.baseUrl}/plans${openOnly ? '?openOnly=true' : ''}`,
      ),
    );
  }

  savePlan(input: PlanInput): Promise<ProductionPlan> {
    return this.unwrap(this.http.post<ApiResponse<ProductionPlan>>(`${this.baseUrl}/plans`, input));
  }

  planCommand(
    id: string,
    command: 'commit' | 'recalculate' | 'accept-recalculation' | 'cancel',
    reason?: string,
  ): Promise<ProductionPlan> {
    return this.unwrap(
      this.http.post<ApiResponse<ProductionPlan>>(
        `${this.baseUrl}/plans/${enc(id)}/${command}`,
        reason ? { reason } : {},
      ),
    );
  }

  searchSchedule(input: ScheduleSearchInput): Promise<ScheduleOptions> {
    return this.unwrap(
      this.http.post<ApiResponse<ScheduleOptions>>(`${this.baseUrl}/schedule/search`, input),
    );
  }

  occupancy(): Promise<HouseOccupancy[]> {
    return this.unwrap(this.http.get<ApiResponse<HouseOccupancy[]>>(`${this.baseUrl}/occupancy`));
  }

  private command(path: string, body: object): Promise<IncubationBatch> {
    return this.unwrap(
      this.http.post<ApiResponse<IncubationBatch>>(`${this.baseUrl}${path}`, body),
    );
  }

  private async unwrap<T>(request: Observable<ApiResponse<T>>, required = true): Promise<T> {
    const data = await unwrapApi(request);
    if (data === undefined && required) throw new ApiError('server', 200, 'Unexpected response');
    return data as T;
  }
}

function enc(value: string): string {
  return encodeURIComponent(value);
}

function reportQuery(filter: HatchingReportFilter): string {
  const params = new URLSearchParams();
  if (filter.from) params.set('from', filter.from);
  if (filter.to) params.set('to', filter.to);
  const text = params.toString();
  return text ? `?${text}` : '';
}
