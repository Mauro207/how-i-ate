import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { RestaurantService } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';

@Component({
  selector: 'app-suggest-place',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavigationComponent],
  templateUrl: './suggest-place.component.html',
  styleUrl: './suggest-place.component.css'
})
export class SuggestPlaceComponent {
  name = signal('');
  description = signal('');
  address = signal('');
  cuisine = signal('');
  error = signal('');
  loading = signal(false);
  success = signal(false);

  cuisineOptions = ['Pizzeria', 'Ristorante', 'Pub', 'Paninoteca', 'Bar', 'Braceria', 'Enoteca', 'Sushi'];

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

    this.restaurantService.createSuggestion(data).subscribe({
      next: () => {
        this.loading.set(false);
        this.success.set(true);
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(err.error?.message || 'Invio del suggerimento fallito. Per favore riprova.');
      }
    });
  }
}
