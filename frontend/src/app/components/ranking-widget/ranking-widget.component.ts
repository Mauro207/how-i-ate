import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { RestaurantService, RankingItem } from '../../services/restaurant.service';
import { getStarArray } from '../../utils/rating.utils';

@Component({
  selector: 'app-ranking-widget',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './ranking-widget.component.html',
  styleUrl: './ranking-widget.component.css'
})
export class RankingWidgetComponent implements OnInit {
  topRankings = signal<RankingItem[]>([]);
  allRankings = signal<RankingItem[]>([]);
  totalCount = signal(0);
  loading = signal(true);
  error = signal('');
  showFilters = signal(false);
  availableCuisines = signal<string[]>([]);
  excludedCuisines = signal<Set<string>>(new Set());
  private readonly TOP_RANKINGS_COUNT = 5;

  constructor(
    private restaurantService: RestaurantService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.loadRankings();
  }

  loadRankings(): void {
    this.loading.set(true);
    this.restaurantService.getGlobalRankings().subscribe({
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
          ? 'Nessuna classifica disponibile' 
          : 'Errore nel caricamento della classifica';
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

  formatRating(rating: number): string {
    const rounded = Math.round(rating * 4) / 4;
    const whole = Math.floor(rounded);
    const remainder = +(rounded - whole).toFixed(2);

    if (remainder === 0.25) return `${whole}+`;
    if (remainder === 0.75) return `${whole + 1}-`;

    return rounded.toFixed(1);
  }

  toggleFilters(): void {
    this.showFilters.set(!this.showFilters());
  }

  toggleCuisine(cuisine: string): void {
    const excluded = new Set(this.excludedCuisines());
    if (excluded.has(cuisine)) {
      excluded.delete(cuisine);
    } else {
      excluded.add(cuisine);
    }
    this.excludedCuisines.set(excluded);
    this.applyFilters();
  }

  isCuisineExcluded(cuisine: string): boolean {
    return this.excludedCuisines().has(cuisine);
  }

  applyFilters(): void {
    const excluded = this.excludedCuisines();
    const filtered = this.allRankings().filter(r => {
      if (!r.cuisine) return true;
      return !excluded.has(r.cuisine);
    });
    this.totalCount.set(filtered.length);
    this.topRankings.set(filtered.slice(0, this.TOP_RANKINGS_COUNT));
  }
}
