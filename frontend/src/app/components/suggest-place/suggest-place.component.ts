import { Component, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { Router, RouterLink } from '@angular/router';
import { RestaurantService, RestaurantSearchResult } from '../../services/restaurant.service';
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
  instagramUrl = signal('');
  error = signal('');
  loading = signal(false);
  success = signal(false);

  // Duplicate check
  similarRestaurants = signal<RestaurantSearchResult[]>([]);
  showDuplicateWarning = signal(false);
  checkingDuplicate = signal(false);

  // Review form constants (come restaurant-detail)
  private readonly DEFAULT_RATING = 5;
  readonly MIN_RATING = 0.25;
  readonly MAX_RATING = 10;
  readonly RATING_STEP = 0.25;

  // Campi recensione obbligatori
  serviceRating = signal(this.DEFAULT_RATING);
  priceRating = signal(this.DEFAULT_RATING);
  menuRating = signal(this.DEFAULT_RATING);
  comment = signal('');

  cuisineOptions = ['Pizzeria', 'Ristorante', 'Pub', 'Paninoteca', 'Bar', 'Braceria', 'Enoteca', 'Sushi'];

  constructor(
    private restaurantService: RestaurantService,
    private router: Router
  ) {}

  private getSubmitErrorMessage(err: HttpErrorResponse): string {
    if (typeof err.error === 'string' && err.error.trim()) {
      return err.error;
    }

    if (err.error?.message) {
      return err.error.message;
    }

    if (err.status === 0) {
      return 'Connessione al server non disponibile. Verifica la rete e riprova.';
    }

    return 'Invio del suggerimento fallito. Per favore riprova.';
  }

  formatRating(rating: number): string {
    const rounded = Math.round(rating * 4) / 4;
    const whole = Math.floor(rounded);
    const remainder = +(rounded - whole).toFixed(2);
    if (remainder === 0.25) return `${whole}+`;
    if (remainder === 0.75) return `${whole + 1}-`;
    return rounded.toFixed(1);
  }

  onNameBlur(): void {
    const query = this.name().trim();
    if (query.length < 2) {
      this.similarRestaurants.set([]);
      this.showDuplicateWarning.set(false);
      return;
    }
    this.checkingDuplicate.set(true);
    this.restaurantService.searchRestaurants(query).subscribe({
      next: (response) => {
        this.checkingDuplicate.set(false);
        this.similarRestaurants.set(response.restaurants);
        this.showDuplicateWarning.set(response.restaurants.length > 0);
      },
      error: () => {
        this.checkingDuplicate.set(false);
      }
    });
  }

  dismissDuplicateWarning(): void {
    this.showDuplicateWarning.set(false);
  }

  onSubmit(): void {
    if (!this.name().trim()) {
      this.error.set('Il nome del luogo è obbligatorio.');
      return;
    }
    if (
      this.serviceRating() == null ||
      this.priceRating() == null ||
      this.menuRating() == null ||
      !this.comment().trim() || this.comment().trim().length < 5
    ) {
      this.error.set('Compila tutti i campi della recensione (tutti obbligatori, commento minimo 5 caratteri).');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    const data = {
      name: this.name(),
      description: this.description() || undefined,
      address: this.address() || undefined,
      cuisine: this.cuisine() || undefined,
      instagramUrl: this.instagramUrl().trim() || undefined,
      review: {
        serviceRating: this.serviceRating(),
        priceRating: this.priceRating(),
        menuRating: this.menuRating(),
        comment: this.comment().trim()
      }
    };

    this.restaurantService.createSuggestion(data).subscribe({
      next: () => {
        this.loading.set(false);
        this.success.set(true);
      },
      error: (err: HttpErrorResponse) => {
        this.loading.set(false);
        this.error.set(this.getSubmitErrorMessage(err));
      }
    });
  }
}
