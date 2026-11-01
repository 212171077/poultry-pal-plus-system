import { Injectable, inject } from '@angular/core';
import { APP_DB } from '../../data/db/app-db';
import { liveSignal } from '../../data/db/live-signal';
import { ReportRequest } from '../../data/models/local';
import { FarmContextRepository } from '../../data/repositories/repositories';
import { newId } from '../../data/sync/entities';
import { ApiError } from '../../core/http/api-error';
import { ReportsApi } from './reports-api';

/**
 * Email report and schedule requests. They are stored on the device and sent as soon as the server
 * can be reached, so a farmer can ask for a report while offline.
 */
@Injectable({ providedIn: 'root' })
export class ReportQueue {
  private readonly db = inject(APP_DB);
  private readonly api = inject(ReportsApi);
  private readonly context = inject(FarmContextRepository);
  private flushing: Promise<number> | null = null;

  /** Live list of requests that have not been sent yet. Call in an injection context. */
  watchPending() {
    return liveSignal(() => this.db.reportRequests.orderBy('createdAt').toArray(), []);
  }

  async enqueue(request: Pick<ReportRequest, 'kind' | 'coopId' | 'label'>): Promise<void> {
    await this.db.reportRequests.add({
      ...request,
      id: newId(),
      status: 'pending',
      createdAt: new Date().toISOString(),
    });
  }

  async discard(id: string): Promise<void> {
    await this.db.reportRequests.delete(id);
  }

  /** Marks a failed request to be tried again. */
  async retry(id: string): Promise<void> {
    await this.db.reportRequests.update(id, { status: 'pending', lastError: null });
  }

  /** Sends queued requests in order; returns how many were delivered. Stops while unreachable. */
  flush(): Promise<number> {
    this.flushing ??= this.run().finally(() => (this.flushing = null));
    return this.flushing;
  }

  private async run(): Promise<number> {
    const [user, farm] = await Promise.all([this.context.currentUser(), this.context.farm()]);
    if (!user || !farm) return 0;
    let sent = 0;
    const queued = await this.db.reportRequests
      .where('status')
      .equals('pending')
      .sortBy('createdAt');
    for (const request of queued) {
      try {
        if (request.kind === 'REPORT') {
          await this.api.emailReport(farm.id, user.id);
        } else if (request.coopId) {
          await this.api.emailSchedule(farm.id, user.id, request.coopId);
        }
        await this.db.reportRequests.delete(request.id);
        sent++;
      } catch (error) {
        const apiError = ApiError.from(error);
        // Offline or session expired: keep the request and try again later.
        if (apiError.kind === 'network' || apiError.kind === 'unauthorized') break;
        await this.db.reportRequests.update(request.id, {
          status: 'failed',
          lastError: apiError.message,
        });
      }
    }
    return sent;
  }
}
