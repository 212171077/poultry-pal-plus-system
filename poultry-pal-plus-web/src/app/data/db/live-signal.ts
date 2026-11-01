import { DestroyRef, Signal, inject, signal } from '@angular/core';
import { liveQuery } from 'dexie';

/**
 * Runs a Dexie query and keeps the returned signal up to date whenever the queried tables change,
 * including changes made in other tabs. Must be called in an injection context; the subscription
 * ends when that context is destroyed.
 */
export function liveSignal<T>(query: () => T | Promise<T>): Signal<T | undefined>;
export function liveSignal<T>(query: () => T | Promise<T>, initial: T): Signal<T>;
export function liveSignal<T>(query: () => T | Promise<T>, initial?: T): Signal<T | undefined> {
  const value = signal<T | undefined>(initial);
  const subscription = liveQuery(query).subscribe({
    next: (result) => value.set(result),
    error: (error: unknown) => console.error('Local query failed', error),
  });
  inject(DestroyRef).onDestroy(() => subscription.unsubscribe());
  return value.asReadonly();
}
