import { AddressDto, ServerRecord, SyncEntityType, SyncOperationType } from './sync-api';

/** Local sync state of a record, shown as a badge in lists. */
export type SyncStatus = 'synced' | 'pending' | 'failed' | 'conflict';

/** Fields every locally stored, server-synced record carries. Dates are ISO-8601 strings. */
export interface SyncedRecord {
  readonly id: string;
  /** Server version. `null` until the server has accepted the record. */
  readonly version: number | null;
  readonly updatedAt?: string | null;
  readonly updatedBy?: string | null;
  readonly syncStatus: SyncStatus;
}

export type CoopType = 'BROILER' | 'LAYERS';
export type GrowthPhase = 'BROODING_PHASE' | 'GROWING_REARING_PHASE' | 'PRODUCTION_FINISHING_PHASE';
export type PaymentStatus = 'PAID' | 'PENDING';
export type ReminderType = 'FEED' | 'VACCINE' | 'MEDICINE';

export interface LocalFarm extends SyncedRecord {
  readonly farmName: string;
  readonly address?: AddressDto | null;
  readonly createdDate?: string | null;
}

export interface LocalCoop extends SyncedRecord {
  readonly coopName: string;
  readonly coopType: CoopType;
  readonly growthPhase: GrowthPhase;
  readonly numberOfChickens: number;
  readonly chickenArrivalDate?: string | null;
  readonly createdDate?: string | null;
  readonly chickenAge?: string | null;
  readonly active?: boolean;
  readonly responsibleUserIds?: readonly string[] | null;
  readonly phaseTransition?: CoopPhaseTransition | null;
}

/** Phase change the server suggests for a coop, with the coops its flock can move into. */
export interface CoopPhaseTransition {
  readonly currentPhase: GrowthPhase;
  readonly newPhase: GrowthPhase;
  readonly transitionCoops?:
    readonly { readonly id: string; readonly displayName: string }[] | null;
}

interface CoopChild extends SyncedRecord {
  readonly coopId: string;
  readonly createdDate?: string | null;
}

export interface LocalSale extends CoopChild {
  readonly saleDate: string;
  readonly numberOfDozensSold?: number | null;
  readonly salePricePerDozen?: number | null;
  readonly eggSize?: string | null;
  readonly eggPackaging?: string | null;
  readonly quantitySold?: number | null;
  readonly pricePerUnit?: number | null;
  readonly totalEggsSold?: number | null;
  readonly numberOfChickensSold?: number | null;
  readonly salePricePerChicken?: number | null;
  readonly additionalInfo?: string | null;
  readonly recordedBy?: string | null;
  readonly paymentStatus?: PaymentStatus | null;
  readonly totalSaleAmount?: number | null;
}

export interface LocalMortality extends CoopChild {
  readonly dateOccurred: string;
  readonly numberOfDeaths: number;
  readonly reason: string;
  readonly recordedBy?: string | null;
}

export interface LocalExpense extends CoopChild {
  readonly expenseDate: string;
  readonly expenseType: string;
  readonly amount: number;
  readonly additionalInfo?: string | null;
  readonly recordedBy?: string | null;
}

export interface LocalEggRecord extends CoopChild {
  /** Packaging date; mirrors the server `createdDate`. */
  readonly createdDate: string;
  readonly eggSize?: string | null;
  readonly boxSize: string;
  readonly numberOfBoxes: number;
  readonly totalEggs?: number | null;
  readonly additionalInfo?: string | null;
}

/** One vaccine, feed or medicine task from a coop's reminder schedule (flattened for querying). */
export interface LocalReminder {
  readonly id: string;
  readonly coopId: string;
  readonly reminderType: ReminderType;
  readonly name: string;
  readonly purpose?: string | null;
  readonly notes?: string | null;
  readonly dueDate?: string | null;
  readonly doneDate?: string | null;
  readonly done: boolean;
  readonly action?: string | null;
  readonly actionComment?: string | null;
  readonly syncStatus: SyncStatus;
}

/** An emailed report or schedule the user asked for; sent when the server is reachable. */
export interface ReportRequest {
  readonly id: string;
  readonly kind: 'REPORT' | 'SCHEDULE';
  /** Required for `SCHEDULE`. */
  readonly coopId: string | null;
  readonly label: string;
  readonly status: 'pending' | 'failed';
  readonly createdAt: string;
  readonly lastError?: string | null;
}

export type OutboxStatus = 'pending' | 'inflight' | 'failed' | 'conflict';

/** A queued change waiting to be pushed to `POST /api/v1/sync/push`. */
export interface OutboxOperation {
  /** Auto-incremented FIFO order. */
  readonly seq?: number;
  readonly opId: string;
  readonly entityType: SyncEntityType;
  readonly operation: SyncOperationType;
  readonly entityId: string;
  readonly coopId: string | null;
  readonly baseVersion: number | null;
  readonly payload: Readonly<Record<string, unknown>> | null;
  readonly status: OutboxStatus;
  /** Times the operation was sent. Operations that were sent are never coalesced. */
  readonly attempts: number;
  /** Payload fields the user changed; drives field-level conflict merging. */
  readonly fields: readonly string[];
  /** Record as last synced before this change; used to merge and to undo on discard. */
  readonly baseRecord?: Readonly<Record<string, unknown>> | null;
  /** Human-readable summary for the Sync Center. */
  readonly label: string;
  readonly createdAt: string;
  readonly lastError?: string | null;
  readonly errorCode?: string | null;
  readonly errors?: readonly string[] | null;
}

/** A change the server refused because the record changed there too. */
export interface SyncConflict {
  readonly opId: string;
  readonly entityType: SyncEntityType;
  readonly entityId: string;
  readonly coopId: string | null;
  readonly label: string;
  readonly message: string;
  /** Fields changed on both sides with different values. */
  readonly fields: readonly string[];
  readonly local: Readonly<Record<string, unknown>> | null;
  readonly server: ServerRecord | null;
  readonly createdAt: string;
}

export interface LocalUser {
  readonly id: string;
  readonly farmId?: string | null;
  readonly name?: string | null;
  readonly surname?: string | null;
  readonly email?: string | null;
  readonly phoneNumber?: string | null;
  readonly farmOwner?: boolean;
  readonly active?: boolean;
  readonly roles?: readonly string[] | null;
  readonly roleFriendlyNames?: readonly string[] | null;
  readonly userCoopIds?: readonly string[] | null;
  /** True for the signed-in user. */
  readonly current?: boolean;
}

export interface LocalSettings {
  readonly userId: string;
  readonly farmId?: string | null;
  readonly currency?: string | null;
  readonly autoCreateReminders?: boolean | null;
  readonly salesAlerts?: boolean | null;
  readonly mortalityAlerts?: boolean | null;
  readonly expenseAlerts?: boolean | null;
  readonly dailyReminders?: boolean | null;
}

export type SyncMetaKey =
  | 'cursor'
  | 'lastSyncedAt'
  | 'userId'
  | 'farmId'
  | 'lastError'
  /** 1 when the user chose "Keep me signed in", 0 otherwise. */
  | 'rememberMe';

export interface SyncMetaEntry {
  readonly key: SyncMetaKey;
  readonly value: string | number | null;
}
