import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { APP_CONFIG } from '../config/app-config';
import { apiInterceptor, isApiUrl } from './api.interceptor';

describe('apiInterceptor', () => {
  let http: HttpClient;
  let controller: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        { provide: APP_CONFIG, useValue: { production: false, apiBaseUrl: '/api' } },
        provideHttpClient(withInterceptors([apiInterceptor])),
        provideHttpClientTesting(),
      ],
    });
    http = TestBed.inject(HttpClient);
    controller = TestBed.inject(HttpTestingController);
  });

  afterEach(() => controller.verify());

  it('sends cookies to the backend API', () => {
    http.get('/api/v1/auth/me').subscribe();
    expect(controller.expectOne('/api/v1/auth/me').request.withCredentials).toBeTrue();
  });

  it('does not send cookies to other origins', () => {
    http.get('https://example.com/data.json').subscribe();
    expect(
      controller.expectOne('https://example.com/data.json').request.withCredentials,
    ).toBeFalse();
  });

  it('matches only the API base path', () => {
    expect(isApiUrl('/api', '/api')).toBeTrue();
    expect(isApiUrl('/api/v1/sync', '/api')).toBeTrue();
    expect(isApiUrl('/apiary', '/api')).toBeFalse();
  });
});
