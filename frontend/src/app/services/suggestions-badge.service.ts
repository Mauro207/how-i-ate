import { Injectable, inject, signal } from '@angular/core';
import { RestaurantService } from './restaurant.service';
import { AuthService } from './auth.service';

@Injectable({
  providedIn: 'root'
})
export class SuggestionsBadgeService {
  private static readonly CACHE_TTL_MS = 30_000;

  readonly pendingCount = signal(0);
  readonly loading = signal(false);

  private readonly restaurantService = inject(RestaurantService);
  private readonly authService = inject(AuthService);

  private lastLoadedAt = 0;
  private inFlight = false;

  canViewSuggestions(): boolean {
    const role = this.authService.currentUser()?.role;
    return role === 'admin' || role === 'superadmin';
  }

  refreshPendingCount(force = false): void {
    if (!this.canViewSuggestions()) {
      this.pendingCount.set(0);
      return;
    }

    const now = Date.now();
    const isFresh = now - this.lastLoadedAt < SuggestionsBadgeService.CACHE_TTL_MS;

    if (!force && (this.inFlight || isFresh)) {
      return;
    }

    this.inFlight = true;
    this.loading.set(true);

    this.restaurantService.getSuggestions().subscribe({
      next: (response) => {
        this.pendingCount.set(response.count || 0);
        this.lastLoadedAt = Date.now();
        this.inFlight = false;
        this.loading.set(false);
      },
      error: () => {
        this.inFlight = false;
        this.loading.set(false);
      }
    });
  }

  setPendingCount(count: number): void {
    this.pendingCount.set(Math.max(0, count));
    this.lastLoadedAt = Date.now();
  }

  invalidate(): void {
    this.lastLoadedAt = 0;
  }
}
