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
  totalCount = signal(0);
  loading = signal(true);
  error = signal('');
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
        this.totalCount.set(response.rankings.length);
        this.topRankings.set(response.rankings.slice(0, this.TOP_RANKINGS_COUNT));
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
}
