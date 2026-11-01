import { Directive, TemplateRef, ViewContainerRef, effect, inject, input } from '@angular/core';
import { AuthService } from './auth.service';
import { Permission } from './permissions';

/**
 * Renders its content only when the signed-in user has the permission, e.g.
 * `<button *appCan="'FARM_MANAGER'">Add coop</button>`. This hides actions; the server still
 * enforces the rule.
 */
@Directive({ selector: '[appCan]' })
export class CanDirective {
  readonly appCan = input.required<Permission>();

  private readonly template = inject(TemplateRef<unknown>);
  private readonly container = inject(ViewContainerRef);
  private readonly auth = inject(AuthService);
  private shown = false;

  constructor() {
    effect(() => {
      const allowed = this.auth.can(this.appCan());
      if (allowed && !this.shown) {
        this.container.createEmbeddedView(this.template);
      } else if (!allowed && this.shown) {
        this.container.clear();
      }
      this.shown = allowed;
    });
  }
}
