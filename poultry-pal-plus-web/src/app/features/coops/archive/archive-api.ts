import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { APP_CONFIG } from '../../../core/config/app-config';
import { ApiError, unwrapApi } from '../../../core/http/api-error';
import { ApiResponse } from '../../../core/http/api-response';

/** Mirrors the backend `ArchivedBatchResponse`. */
export interface ArchivedBatch {
  readonly id: string;
  readonly coopId?: string | null;
  readonly coopName?: string | null;
  readonly coopType?: string | null;
  readonly growthPhase?: string | null;
  readonly numberOfChickens: number;
  readonly chickenArrivalDate?: string | null;
  readonly archivedDate?: string | null;
  readonly totalSales: number;
  readonly totalExpenses: number;
  readonly totalDeaths: number;
  readonly totalEggs: number;
  readonly salesCount: number;
  readonly expensesCount: number;
  readonly mortalityCount: number;
  readonly eggRecordCount: number;
}

/** Client for `GET /api/v1/farm/archived-batches` (online only; archives are history, not synced). */
@Injectable({ providedIn: 'root' })
export class ArchiveApi {
  private readonly http = inject(HttpClient);
  private readonly baseUrl = `${inject(APP_CONFIG).apiBaseUrl}/v1/farm`;

  async archivedBatches(): Promise<ArchivedBatch[]> {
    const batches = await unwrapApi(
      this.http.get<ApiResponse<ArchivedBatch[]>>(`${this.baseUrl}/archived-batches`),
    );
    if (!batches) throw new ApiError('server', 200, 'Unexpected response');
    return batches;
  }
}

/** Net result of a batch: sales minus expenses. */
export function batchProfit(batch: ArchivedBatch): number {
  return batch.totalSales - batch.totalExpenses;
}

/** Share of the placed birds that died, as a percentage (0 when none were placed). */
export function batchMortalityRate(batch: ArchivedBatch): number {
  return batch.numberOfChickens > 0 ? (batch.totalDeaths / batch.numberOfChickens) * 100 : 0;
}
