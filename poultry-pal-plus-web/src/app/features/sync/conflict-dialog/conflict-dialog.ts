import { ChangeDetectionStrategy, Component, computed, inject } from '@angular/core';
import { MatButtonModule } from '@angular/material/button';
import { MAT_DIALOG_DATA, MatDialogModule } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon';
import { format } from 'date-fns';
import { SyncConflict } from '../../../data/models/local';
import { sameValue } from '../../../data/sync/conflict-merge';
import { entityDef } from '../../../data/sync/entities';

export type ConflictChoice = 'mine' | 'server';

export interface ConflictDialogData {
  readonly conflict: SyncConflict;
}

interface FieldRow {
  readonly field: string;
  readonly label: string;
  readonly mine: string;
  readonly server: string;
}

/** Shows the user's change next to the server's copy so they can pick which one to keep. */
@Component({
  selector: 'app-conflict-dialog',
  imports: [MatDialogModule, MatButtonModule, MatIconModule],
  template: `
    <h2 mat-dialog-title>Review conflicting change</h2>
    <mat-dialog-content>
      <p class="intro">
        <strong>{{ data.conflict.label }}</strong> was changed on another device before your change
        reached the server.
      </p>
      @if (deletedOnServer()) {
        <p class="note">
          <mat-icon aria-hidden="true">delete_outline</mat-icon>
          This record was deleted on the server. Keep yours to restore it with your changes.
        </p>
      } @else if (deletedLocally()) {
        <p class="note">
          <mat-icon aria-hidden="true">delete_outline</mat-icon>
          You deleted this record. Keep yours to delete it anyway, or keep the server's copy.
        </p>
      }
      @if (rows().length > 0) {
        <div class="table" role="table" aria-label="Changed fields">
          <div class="row head" role="row">
            <span role="columnheader">Field</span>
            <span role="columnheader">Your change</span>
            <span role="columnheader">On the server</span>
          </div>
          @for (row of rows(); track row.field) {
            <div class="row" role="row">
              <span role="rowheader">{{ row.label }}</span>
              <span role="cell" class="mine">{{ row.mine }}</span>
              <span role="cell">{{ row.server }}</span>
            </div>
          }
        </div>
      }
    </mat-dialog-content>
    <mat-dialog-actions align="end">
      <button mat-button type="button" mat-dialog-close>Decide later</button>
      <button mat-stroked-button type="button" [mat-dialog-close]="'server'">
        Keep server version
      </button>
      <button mat-flat-button type="button" [mat-dialog-close]="'mine'">Keep mine</button>
    </mat-dialog-actions>
  `,
  styles: `
    .intro {
      margin-bottom: var(--pp-space-md);
    }
    .note {
      display: flex;
      align-items: center;
      gap: var(--pp-space-sm);
      margin-bottom: var(--pp-space-md);
      padding: var(--pp-space-sm) var(--pp-space-md);
      border-radius: var(--pp-radius-md);
      background: var(--pp-warning-container);
    }
    .table {
      display: grid;
      border: 1px solid var(--pp-border);
      border-radius: var(--pp-radius-md);
      overflow: hidden;
    }
    .row {
      display: grid;
      grid-template-columns: minmax(90px, 1fr) 1.2fr 1.2fr;
      gap: var(--pp-space-sm);
      padding: var(--pp-space-sm) var(--pp-space-md);
      border-top: 1px solid var(--pp-border);
      overflow-wrap: anywhere;
    }
    .row.head {
      border-top: none;
      background: var(--pp-surface-warm);
      font-weight: 600;
    }
    .mine {
      color: var(--pp-brand-strong);
      font-weight: 600;
    }
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class ConflictDialog {
  protected readonly data = inject<ConflictDialogData>(MAT_DIALOG_DATA);

  protected readonly deletedOnServer = computed(() => this.data.conflict.server === null);
  protected readonly deletedLocally = computed(() => this.data.conflict.local === null);

  protected readonly rows = computed<FieldRow[]>(() => {
    const { conflict } = this.data;
    const local = conflict.local ?? {};
    const server = conflict.server ?? {};
    const candidates = conflict.fields.length
      ? conflict.fields
      : (entityDef(conflict.entityType)?.payloadFields ?? Object.keys(local));
    return candidates
      .filter((field) => conflict.fields.length || !sameValue(local[field], server[field]))
      .map((field) => ({
        field,
        label: humanize(field),
        mine: conflict.local ? display(local[field]) : 'Deleted',
        server: conflict.server ? display(server[field]) : 'Deleted',
      }));
  });
}

function humanize(field: string): string {
  const words = field.replace(/([A-Z])/g, ' $1').toLowerCase();
  return words.charAt(0).toUpperCase() + words.slice(1);
}

function display(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T/.test(value)) {
    const date = new Date(value);
    if (!Number.isNaN(date.getTime())) return format(date, 'd MMM yyyy');
  }
  if (typeof value === 'number') return value.toLocaleString();
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}
