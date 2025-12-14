import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { RestaurantService, RankingItem } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';

@Component({
  selector: 'app-rankings',
  standalone: true,
  imports: [CommonModule, RouterLink, NavigationComponent],
  templateUrl: './rankings.component.html',
  styleUrl: './rankings.component.css'
})
export class RankingsComponent implements OnInit {
  rankings = signal<RankingItem[]>([]);
  filtered = signal<RankingItem[]>([]);
  totalCount = signal(0);
  loading = signal(true);
  error = signal('');
  showFilters = signal(false);
  availableCuisines = signal<string[]>([]);
  includedCuisines = signal<Set<string>>(new Set());

  constructor(private restaurantService: RestaurantService, private router: Router) {}

  ngOnInit(): void {
    this.loadRankings();
  }

  loadRankings(): void {
    this.loading.set(true);
    this.restaurantService.getGlobalRankings().subscribe({
      next: (response) => {
        this.rankings.set(response.rankings);
        const cuisines = new Set<string>();
        response.rankings.forEach((r) => {
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
    const included = new Set(this.includedCuisines());
    included.has(cuisine) ? included.delete(cuisine) : included.add(cuisine);
    this.includedCuisines.set(included);
    this.applyFilters();
  }

  isCuisineIncluded(cuisine: string): boolean {
    return this.includedCuisines().has(cuisine);
  }

  applyFilters(): void {
    const included = this.includedCuisines();
    const all = this.rankings();
    if (included.size === 0) {
      this.filtered.set(all);
      this.totalCount.set(all.length);
      return;
    }
    const filtered = all.filter((r) => r.cuisine && included.has(r.cuisine));
    this.filtered.set(filtered);
    this.totalCount.set(filtered.length);
  }
}
