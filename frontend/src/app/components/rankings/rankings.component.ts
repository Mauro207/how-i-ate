import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
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
  private retryAttempted = false;
  showFilters = signal(false);
  availableCuisines = signal<string[]>([]);
  includedCuisines = signal<Set<string>>(new Set());

  constructor(
    private restaurantService: RestaurantService,
    private router: Router,
    private route: ActivatedRoute
  ) {}

  ngOnInit(): void {
    this.restoreFiltersFromQueryParams();
    this.loadRankings();
  }

  loadRankings(): void {
    this.loading.set(true);
    this.error.set('');
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
        this.retryAttempted = false;
      },
      error: (err) => {
        if (!this.retryAttempted && err.status === 0) {
          this.retryAttempted = true;
          setTimeout(() => this.loadRankings(), 2000);
        } else {
          this.error.set(this.httpErrorMessage(err, 'Caricamento della classifica fallito'));
          this.loading.set(false);
          this.retryAttempted = false;
        }
      }
    });
  }

  viewRestaurant(restaurantId: string): void {
    this.router.navigate(['/restaurants', restaurantId]);
  }

  private httpErrorMessage(err: any, context: string): string {
    if (err.status === 0) {
      return `${context}: impossibile raggiungere il server. Verifica la connessione e riprova.`;
    }
    if (err.status === 401) {
      return `${context}: sessione scaduta. Effettua nuovamente l'accesso.`;
    }
    if (err.status === 403) {
      return `${context}: accesso non autorizzato.`;
    }
    if (err.status === 404) {
      return `${context}: nessuna classifica disponibile.`;
    }
    if (err.status === 429) {
      return `${context}: troppe richieste. Attendi qualche secondo e riprova.`;
    }
    if (err.status >= 500) {
      return `${context}: errore del server (${err.status}). Riprova più tardi.`;
    }
    return err.error?.message || `${context} (codice: ${err.status ?? 'nessuna risposta'}).`;
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
    this.persistFiltersToQueryParams();
  }

  toggleCuisine(cuisine: string): void {
    const included = new Set(this.includedCuisines());
    included.has(cuisine) ? included.delete(cuisine) : included.add(cuisine);
    this.includedCuisines.set(included);
    this.applyFilters();
    this.persistFiltersToQueryParams();
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

  private restoreFiltersFromQueryParams(): void {
    const queryMap = this.route.snapshot.queryParamMap;
    const showFilters = queryMap.get('filters') === '1';
    const cuisinesParam = queryMap.get('cuisines') || '';
    const cuisines = cuisinesParam
      .split(',')
      .map((c) => c.trim())
      .filter(Boolean);

    this.showFilters.set(showFilters);
    this.includedCuisines.set(new Set(cuisines));
  }

  private persistFiltersToQueryParams(): void {
    const cuisines = Array.from(this.includedCuisines()).sort();
    this.router.navigate([], {
      relativeTo: this.route,
      queryParams: {
        filters: this.showFilters() ? '1' : null,
        cuisines: cuisines.length > 0 ? cuisines.join(',') : null
      },
      queryParamsHandling: 'merge',
      replaceUrl: true
    });
  }
}
