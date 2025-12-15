import { Component, OnInit, OnDestroy, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Subscription } from 'rxjs';
import { RestaurantService, UserRankingItem } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';
import { getStarArray } from '../../utils/rating.utils';

@Component({
  selector: 'app-user-rankings',
  standalone: true,
  imports: [CommonModule, RouterLink, NavigationComponent],
  templateUrl: './user-rankings.component.html',
  styleUrl: './user-rankings.component.css'
})
export class UserRankingsComponent implements OnInit, OnDestroy {
  rankings = signal<UserRankingItem[]>([]);
  allRankings = signal<UserRankingItem[]>([]);
  loading = signal(true);
  error = signal('');
  userId = signal('');
  username = signal('');
  showFilters = signal(false);
  availableCuisines = signal<string[]>([]);
  includedCuisines = signal<Set<string>>(new Set());
  private readonly DEFAULT_USERNAME = 'Utente';
  private routeSubscription?: Subscription;

  constructor(
    private restaurantService: RestaurantService,
    private route: ActivatedRoute,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.routeSubscription = this.route.paramMap.subscribe(params => {
      const userId = params.get('userId');
      const username = params.get('username');
      if (userId) {
        this.userId.set(userId);
        this.username.set(username || this.DEFAULT_USERNAME);
        this.loadUserRankings(userId);
      }
    });
  }

  ngOnDestroy(): void {
    this.routeSubscription?.unsubscribe();
  }

  loadUserRankings(userId: string): void {
    this.loading.set(true);
    this.restaurantService.getUserRankings(userId).subscribe({
      next: (response) => {
        this.allRankings.set(response.rankings);
        const cuisines = new Set<string>();
        response.rankings.forEach(r => {
          if (r.cuisine) cuisines.add(r.cuisine);
        });
        this.availableCuisines.set(Array.from(cuisines).sort());
        this.applyFilters();
        this.loading.set(false);
      },
      error: (err) => {
        const errorMsg = err.status === 404 
          ? 'Utente non trovato' 
          : 'Errore nel caricamento delle recensioni dell\'utente';
        this.error.set(errorMsg);
        this.loading.set(false);
      }
    });
  }

  viewRestaurant(restaurantId: string): void {
    this.router.navigate(['/restaurants', restaurantId]);
  }

  getStarArray(rating: number): number[] {
    return getStarArray(rating);
  }

  toggleFilters(): void {
    this.showFilters.set(!this.showFilters());
  }

  toggleCuisine(cuisine: string): void {
    const included = new Set(this.includedCuisines());
    if (included.has(cuisine)) {
      included.delete(cuisine);
    } else {
      included.add(cuisine);
    }
    this.includedCuisines.set(included);
    this.applyFilters();
  }

  isCuisineIncluded(cuisine: string): boolean {
    return this.includedCuisines().has(cuisine);
  }

  formatRating(rating: number): string {
    const rounded = Math.round(rating * 4) / 4;
    const whole = Math.floor(rounded);
    const remainder = +(rounded - whole).toFixed(2);

    if (remainder === 0.25) return `${whole}+`;
    if (remainder === 0.75) return `${whole + 1}-`;

    return rounded.toFixed(1);
  }

  applyFilters(): void {
    const included = this.includedCuisines();
    // If no cuisines are selected, show all
    if (included.size === 0) {
      this.rankings.set(this.allRankings());
      return;
    }
    // Otherwise, show only selected cuisines
    const filtered = this.allRankings().filter(r => {
      if (!r.cuisine) return false;
      return included.has(r.cuisine);
    });
    this.rankings.set(filtered);
  }
}
