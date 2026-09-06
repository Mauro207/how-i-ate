import { Component, OnDestroy, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router } from '@angular/router';
import { Subscription } from 'rxjs';
import { AuthService, UserProfile } from '../../services/auth.service';
import { RestaurantService } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';
import { InviteComponent } from '../invite/invite.component';
import { LoadingIndicatorComponent } from '../loading-indicator/loading-indicator.component';

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, NavigationComponent, InviteComponent, LoadingIndicatorComponent],
  templateUrl: './user-profile.component.html',
  styleUrl: './user-profile.component.css'
})
export class UserProfileComponent implements OnInit, OnDestroy {
  profile = signal<UserProfile | null>(null);
  loading = signal(true);
  error = signal('');
  userId = signal('');
  fallbackUsername = signal('');

  displayName = computed(() => {
    const user = this.profile()?.user;
    if (!user) return this.fallbackUsername() || 'Utente';
    return user.displayName?.trim() ? user.displayName : user.username;
  });

  username = computed(() => this.profile()?.user.username || this.fallbackUsername());

  private readonly authService = inject(AuthService);
  private readonly restaurantService = inject(RestaurantService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private routeSubscription?: Subscription;

  ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const userId = params.get('userId');
      const username = params.get('username') || this.route.snapshot.queryParamMap.get('username') || '';

      if (!userId) {
        this.error.set('Utente non trovato');
        this.loading.set(false);
        return;
      }

      this.userId.set(userId);
      this.fallbackUsername.set(username);
      this.loadProfile(userId);
    });
  }

  ngOnDestroy(): void {
    this.routeSubscription?.unsubscribe();
  }

  loadProfile(userId: string): void {
    this.loading.set(true);
    this.error.set('');

    this.authService.getUserProfile(userId).subscribe({
      next: profile => {
        this.profile.set(profile);
        this.loading.set(false);
      },
      error: err => {
        if (err.status === 404) {
          this.loadLegacyProfileFallback(userId);
          return;
        }

        this.error.set('Errore nel caricamento del profilo');
        this.loading.set(false);
      }
    });
  }

  openRankings(): void {
    const username = this.username();
    if (username) {
      this.router.navigate(['/user-rankings', this.userId(), username]);
      return;
    }

    this.router.navigate(['/user-rankings', this.userId()]);
  }

  isOwnProfile(): boolean {
    return this.authService.currentUser()?.id === this.userId();
  }

  openSettings(): void {
    if (this.isOwnProfile()) {
      this.router.navigate(['/settings']);
    }
  }

  private loadLegacyProfileFallback(userId: string): void {
    this.restaurantService.getUserRankings(userId).subscribe({
      next: response => {
        const username = this.fallbackUsername() || 'Utente';
        this.profile.set({
          user: {
            id: userId,
            username,
            role: 'user'
          },
          stats: {
            reviewCount: response.rankings.length,
            suggestedPlaceCount: null
          }
        });
        this.loading.set(false);
      },
      error: () => {
        this.error.set('Utente non trovato');
        this.loading.set(false);
      }
    });
  }
}
