import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { RestaurantService } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';

@Component({
  selector: 'app-restaurant-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavigationComponent],
  templateUrl: './restaurant-create.component.html',
  styleUrl: './restaurant-create.component.css'
})
export class RestaurantCreateComponent {
  name = signal('');
  description = signal('');
  address = signal('');
  cuisine = signal('');
  error = signal('');
  loading = signal(false);

  cuisineOptions = ['Pizzeria', 'Ristorante', 'Pub', 'Paninoteca', 'Sushi']; 
  
  constructor(
    private restaurantService: RestaurantService,
    private router: Router
  ) {}

  onSubmit(): void {
    if (!this.name().trim()) {
      this.error.set('Il nome del luogo è obbligatorio.');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    const data = {
      name: this.name(),
      description: this.description() || undefined,
      address: this.address() || undefined,
      cuisine: this.cuisine() || undefined
    };

    this.restaurantService.createRestaurant(data).subscribe({
      next: (response) => {
        this.router.navigate(['/restaurants', response.restaurant._id]);
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(err.error?.message || 'Creazione del luogo fallita. Per favore riprova.');
      }
    });
  }
}
