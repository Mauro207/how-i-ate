import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { RestaurantService, Restaurant } from '../../services/restaurant.service';
import { AuthService } from '../../services/auth.service';
import { NavigationComponent } from '../navigation/navigation.component'; 

@Component({
  selector: 'app-restaurants',
  standalone: true,
  imports: [CommonModule, RouterLink, NavigationComponent],
  templateUrl: './restaurants.component.html',
  styleUrl: './restaurants.component.css'
})
export class RestaurantsComponent implements OnInit {
  restaurants = signal<Restaurant[]>([]);
  loading = signal(true);
  error = signal('');

  constructor(
    public restaurantService: RestaurantService,
    public authService: AuthService,
    private router: Router
  ) {}

  ngOnInit(): void {
    this.loadRestaurants();
  }

  loadRestaurants(): void {
    this.loading.set(true);
    this.restaurantService.getRestaurants().subscribe({
      next: (restaurants) => {
        this.restaurants.set(restaurants);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set('Failed to load restaurants');
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
