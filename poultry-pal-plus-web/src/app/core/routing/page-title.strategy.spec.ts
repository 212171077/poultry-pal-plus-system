import { Component } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { Title } from '@angular/platform-browser';
import { Router, TitleStrategy, provideRouter } from '@angular/router';
import { PageTitleStrategy } from './page-title.strategy';

@Component({ template: '' })
class Blank {}

describe('PageTitleStrategy', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: 'sales', title: 'Sales', component: Blank },
          { path: 'untitled', component: Blank },
        ]),
        { provide: TitleStrategy, useClass: PageTitleStrategy },
      ],
    });
  });

  it('suffixes the page title with the app name', async () => {
    await TestBed.inject(Router).navigateByUrl('/sales');
    expect(TestBed.inject(Title).getTitle()).toBe('Sales · Poultry Pal Plus');
  });

  it('falls back to the app name', async () => {
    await TestBed.inject(Router).navigateByUrl('/untitled');
    expect(TestBed.inject(Title).getTitle()).toBe('Poultry Pal Plus');
  });
});
