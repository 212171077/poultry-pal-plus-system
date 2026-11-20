/**
 * Wire types for the backend `/api/v1/sync` and `/api/v1/auth` endpoints. They mirror the Java DTOs
 * in `poultry-pal-service/.../model/payload/{request,response}/sync`. Dates arrive as ISO-8601 strings
 * (Spring Boot default) but older payloads may use epoch millis, so both are accepted on input.
 */

export type SyncEntityType =
  'FARM' | 'COOP' | 'SALE' | 'MORTALITY' | 'EXPENSE' | 'EGG_PACKAGING' | 'REMINDER' | 'PRODUCTION';

export type SyncOperationType = 'UPSERT' | 'DELETE' | 'ACTION';

/** Payload of a `COOP` `ACTION` (backend `CoopActionPayload`). */
export type CoopActionPayload =
  | {
      readonly action: 'NEW_BATCH';
      /** The new batch, shaped like a coop UPSERT payload. */
      readonly batch: Readonly<Record<string, unknown>>;
    }
  | {
      readonly action: 'PHASE_TRANSITION';
      readonly newGrowthPhase: string;
      /** Empty coop of the same type to move the flock into; `null` changes the phase in place. */
      readonly targetCoopId: string | null;
    };

export type SyncOperationStatus = 'APPLIED' | 'CONFLICT' | 'REJECTED';

export type WireDate = string | number;

/** Untyped server record (`Map<String, Object>` on the backend). */
export type ServerRecord = Readonly<Record<string, unknown>>;

export interface SyncOperationDto {
  readonly opId: string;
  readonly entityType: SyncEntityType;
  readonly operation: SyncOperationType;
  readonly entityId: string;
  readonly coopId: string | null;
  readonly baseVersion: number | null;
  readonly payload: Readonly<Record<string, unknown>> | null;
}

export interface SyncPushRequest {
  readonly operations: readonly SyncOperationDto[];
}

export interface SyncOperationResult {
  readonly opId: string;
  readonly status: SyncOperationStatus;
  readonly entityType: SyncEntityType;
  readonly entityId: string;
  readonly coopId?: string | null;
  readonly version?: number | null;
  readonly duplicate?: boolean;
  readonly errorCode?: string | null;
  readonly message?: string | null;
  readonly errors?: readonly string[] | null;
  readonly serverRecord?: ServerRecord | null;
}

export interface SyncPushResponse {
  readonly results: readonly SyncOperationResult[];
  readonly serverVersion: number;
}

export interface AddressDto {
  readonly id?: string | null;
  readonly label?: string | null;
  readonly addressLine1?: string | null;
  readonly addressLine2?: string | null;
  readonly state?: string | null;
  readonly city?: string | null;
  readonly postalCode?: string | null;
  readonly country?: string | null;
}

export interface FarmSnapshot {
  readonly id: string;
  readonly farmName: string;
  readonly address?: AddressDto | null;
  readonly addresses?: readonly AddressDto[] | null;
  readonly createdDate?: WireDate | null;
  readonly updatedAt?: WireDate | null;
  readonly version: number;
}

export interface SyncTombstone {
  readonly entityType: SyncEntityType;
  readonly entityId: string;
  readonly coopId?: string | null;
  readonly version?: number | null;
  readonly deletedAt?: WireDate | null;
}

export interface SyncChangesResponse {
  readonly cursor: number;
  readonly hasMore: boolean;
  readonly resetRequired: boolean;
  readonly farm?: FarmSnapshot | null;
  readonly coops?: readonly ServerRecord[];
  readonly sales?: readonly ServerRecord[];
  readonly mortalities?: readonly ServerRecord[];
  readonly expenses?: readonly ServerRecord[];
  readonly eggPackagingRecords?: readonly ServerRecord[];
  readonly tombstones?: readonly SyncTombstone[];
}

/** `UserInfoResponse`. Lombok `boolean isX` fields serialize without the `is` prefix. */
export interface UserInfo {
  readonly id: string;
  readonly name?: string | null;
  readonly surname?: string | null;
  readonly phoneNumber?: string | null;
  readonly farmId?: string | null;
  readonly farmOwner?: boolean;
  readonly active?: boolean;
  readonly createdDate?: WireDate | null;
  readonly email?: string | null;
  readonly roles?: readonly string[] | null;
  readonly userCoopIds?: readonly string[] | null;
  readonly roleFriendlyNames?: readonly string[] | null;
  readonly permissions?: readonly string[] | null;
}

export interface UserSettings {
  readonly id?: string | null;
  readonly userId: string;
  readonly farmId?: string | null;
  readonly currency?: string | null;
  readonly autoCreateReminders?: boolean | null;
  readonly salesAlerts?: boolean | null;
  readonly mortalityAlerts?: boolean | null;
  readonly expenseAlerts?: boolean | null;
  readonly dailyReminders?: boolean | null;
}

export interface SyncBootstrapResponse {
  readonly user: UserInfo;
  readonly snapshot: SyncChangesResponse;
  readonly team?: readonly UserInfo[] | null;
  readonly settings?: UserSettings | null;
}
