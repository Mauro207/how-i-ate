import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { RestaurantService } from '../../services/restaurant.service';

interface RankingItem {
  restaurantId: string;
  restaurantName: string;
  cuisine?: string;
  averageRating: number;
  reviewCount: number;
}

@Component({
  selector: 'app-ranking-widget',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './ranking-widget.component.html',
  styleUrl: './ranking-widget.component.css'
})
export class RankingWidgetComponent implements OnInit {
  rankings = signal<RankingItem[]>([]);
  loading = signal(true);
  error = signal('');

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
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set('Failed to load rankings');
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
