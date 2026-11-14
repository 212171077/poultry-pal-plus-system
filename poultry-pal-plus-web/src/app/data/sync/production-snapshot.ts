import { Injectable, inject, signal } from '@angular/core';
import { ApiError } from '../../core/http/api-error';
import { hasPermission } from '../../core/auth/permissions';
import { ConnectivityService } from '../../core/network/connectivity.service';
import type { ProductionSnapshot, SnapshotSection } from '../../features/production/production-api';
import { APP_DB } from '../db/app-db';
import { SyncApi } from './sync-api';

type SectionData<K extends SnapshotSection> = ProductionSnapshot[K];

/**
 * Offline copy of the production pages' data. Reads go to the server first and fall back to the last
 * copy; the sync engine refreshes every section after each successful sync.
 */
@Injectable({ providedIn: 'root' })
export class ProductionSnapshotStore {
  private readonly db = inject(APP_DB);
  private readonly api = inject(SyncApi);
  private readonly connectivity = inject(ConnectivityService);

  /** When the data on screen was saved, or `null` while it is live from the server. */
  readonly offlineSince = signal<Date | null>(null);
  /** Increases whenever a refresh replaced the cached data, so pages can reload. */
  readonly changed = signal(0);

  async read<K extends SnapshotSection>(
    section: K,
    fetch: () => Promise<SectionData<K>>,
  ): Promise<SectionData<K>> {
    if (!this.connectivity.online()) {
      const hit = await this.cached(section);
      if (hit) return hit;
    }
    try {
      const data = await fetch();
      await this.put(section, data);
      this.offlineSince.set(null);
      return data;
    } catch (error) {
      if (ApiError.from(error).kind === 'network') {
        const entry = await this.db.productionCache.get(section);
        if (entry) {
          this.offlineSince.set(new Date(entry.fetchedAt));
          return entry.data as SectionData<K>;
        }
      }
      throw error;
    }
  }

  /** Downloads a fresh copy; silently skipped without production access or a connection. */
  async refresh(): Promise<void> {
    const user = (await this.db.users.toArray()).find((u) => u.current);
    if (!hasPermission(user, 'PRODUCTION_MANAGE')) return;
    try {
      const snapshot = await this.api.productionSnapshot();
      const { generatedAt, ...sections } = snapshot;
      await this.db.productionCache.bulkPut(
        Object.entries(sections).map(([key, data]) => ({ key, data, fetchedAt: generatedAt })),
      );
      this.offlineSince.set(null);
      this.changed.update((n) => n + 1);
    } catch {
      // Not enabled for this user or temporarily unreachable: keep what is cached.
    }
  }

  private async cached<K extends SnapshotSection>(section: K): Promise<SectionData<K> | null> {
    const entry = await this.db.productionCache.get(section);
    if (!entry) return null;
    this.offlineSince.set(new Date(entry.fetchedAt));
    return entry.data as SectionData<K>;
  }

  private put(section: SnapshotSection, data: unknown): Promise<string> {
    return this.db.productionCache.put({
      key: section,
      data,
      fetchedAt: new Date().toISOString(),
    });
  }
}
