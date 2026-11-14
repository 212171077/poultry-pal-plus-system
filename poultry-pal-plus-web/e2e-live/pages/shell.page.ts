import { Locator, Page, expect } from '@playwright/test';

/** The signed-in frame: side navigation (desktop), bottom bar + drawer (mobile) and top bar. */
export class ShellPage {
  readonly main: Locator;
  readonly accountMenu: Locator;

  constructor(readonly page: Page) {
    this.main = page.locator('#main-content');
    this.accountMenu = page.getByRole('button', { name: /^Account menu for/ });
  }

  isHandset(): boolean {
    return (this.page.viewportSize()?.width ?? 1920) < 600;
  }

  async expectLoaded(): Promise<void> {
    await expect(this.main).toBeVisible();
    await expect(this.accountMenu).toBeVisible();
  }

  /** On handsets the full navigation is in the drawer behind the bottom bar's "More" button. */
  async openNavigation(): Promise<Locator> {
    if (this.isHandset()) {
      await this.page.getByRole('button', { name: 'More', exact: true }).click();
      const drawer = this.page.locator('mat-sidenav');
      await expect(drawer).toBeVisible();
      // The drawer counts as visible while it is still sliding in.
      await expect
        .poll(async () => (await drawer.boundingBox())?.x ?? -1)
        .toBeGreaterThanOrEqual(0);
      return drawer.getByRole('navigation', { name: 'Main' });
    }
    return this.page.locator('mat-sidenav').getByRole('navigation', { name: 'Main' });
  }

  /** Every navigation label the user can currently see. */
  async navLabels(): Promise<string[]> {
    const nav = await this.openNavigation();
    const labels = await nav.locator('a.link .label').allInnerTexts();
    await this.closeNavigation();
    return labels.map((label) => label.trim());
  }

  /** Closes the handset drawer the way a user does: by tapping the backdrop. */
  async closeNavigation(): Promise<void> {
    if (!this.isHandset()) return;
    const backdrop = this.page.locator('.mat-drawer-backdrop');
    await backdrop.click({ position: { x: this.page.viewportSize()!.width - 10, y: 200 } });
    await expect(backdrop).toBeHidden();
  }

  async goTo(label: string): Promise<void> {
    const nav = await this.openNavigation();
    await nav.getByRole('link', { name: label, exact: true }).click();
  }

  async accountSummary(): Promise<string> {
    await this.accountMenu.click();
    const text = await this.page.locator('.pp-user-menu .account').innerText();
    await this.page.keyboard.press('Escape');
    return text;
  }

  async signOut(): Promise<void> {
    await this.accountMenu.click();
    await this.page.getByRole('menuitem', { name: 'Sign out' }).click();
    await expect(this.page).toHaveURL(/\/login/);
  }
}
