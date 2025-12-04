import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { RestaurantService, RankingItem } from '../../services/restaurant.service';

@Component({
  selector: 'app-ranking-widget',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './ranking-widget.component.html',
  styleUrl: './ranking-widget.component.css'
})
export class RankingWidgetComponent implements OnInit {
  rankings = signal<RankingItem[]>([]);
  topRankings = signal<RankingItem[]>([]);
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
        this.rankings.set(response.rankings);
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
    return Array(5).fill(0).map((_, i) => i < Math.round(rating) ? 1 : 0);
  }
}
