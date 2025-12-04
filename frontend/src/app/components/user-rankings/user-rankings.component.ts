import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { RestaurantService, UserRankingItem } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';

@Component({
  selector: 'app-user-rankings',
  standalone: true,
  imports: [CommonModule, RouterLink, NavigationComponent],
  templateUrl: './user-rankings.component.html',
  styleUrl: './user-rankings.component.css'
})
export class UserRankingsComponent implements OnInit {
  rankings = signal<UserRankingItem[]>([]);
  loading = signal(true);
  error = signal('');
  userId = signal('');
  username = signal('');

  constructor(
    private restaurantService: RestaurantService,
    private route: ActivatedRoute,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.route.paramMap.subscribe(params => {
      const userId = params.get('userId');
      const username = params.get('username');
      if (userId) {
        this.userId.set(userId);
        this.username.set(username || 'Utente');
        this.loadUserRankings(userId);
      }
    });
  }

  loadUserRankings(userId: string): void {
    this.loading.set(true);
    this.restaurantService.getUserRankings(userId).subscribe({
      next: (response) => {
        this.rankings.set(response.rankings);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set('Failed to load user rankings');
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
