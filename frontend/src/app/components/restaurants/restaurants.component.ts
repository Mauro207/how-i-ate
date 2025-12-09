import { Component, OnInit, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { RestaurantService, Restaurant } from '../../services/restaurant.service';
import { AuthService } from '../../services/auth.service';
import { NavigationComponent } from '../navigation/navigation.component';
import { RankingWidgetComponent } from '../ranking-widget/ranking-widget.component'; 
import { Title } from '@angular/platform-browser';

@Component({
  selector: 'app-restaurants',
  standalone: true,
  imports: [CommonModule, RouterLink, NavigationComponent, RankingWidgetComponent],
  templateUrl: './restaurants.component.html',
  styleUrl: './restaurants.component.css'
})
export class RestaurantsComponent implements OnInit {
  restaurants = signal<Restaurant[]>([]);
  recentRestaurants = computed(() => {
    // Ordina per data di creazione decrescente e prendi gli ultimi 5
    return [...this.restaurants()]
      .sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 5);
  });
  loading = signal(true);
  error = signal('');

  constructor(
    public restaurantService: RestaurantService,
    public authService: AuthService,
    private router: Router,
    private title: Title
  ) {}

  ngOnInit(): void {
    this.loadRestaurants();
    this.title.setTitle('Dashboard - How I Ate');
  }

  loadRestaurants(): void {
    this.loading.set(true);
    this.restaurantService.getRestaurants().subscribe({
      next: (restaurants) => {
        this.restaurants.set(restaurants);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set('Caricamento dei luoghi fallito.');
        this.loading.set(false);
      }
    });
  }

  canCreateRestaurant(): boolean {
    const user = this.authService.currentUser();
    return user?.role === 'admin' || user?.role === 'superadmin';
  }

  logout(): void {
    this.authService.logout();
  }

  viewRestaurant(id: string): void {
    this.router.navigate(['/restaurants', id]);
  }
}
