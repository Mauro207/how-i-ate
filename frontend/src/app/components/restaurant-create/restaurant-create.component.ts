import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { RestaurantService } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';

@Component({
  selector: 'app-restaurant-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavigationComponent],
  templateUrl: './restaurant-create.component.html',
  styleUrl: './restaurant-create.component.css'
})
export class RestaurantCreateComponent implements OnInit {
  name = signal('');
  description = signal('');
  address = signal('');
  cuisine = signal('');
  coverImageUrl = signal('');
  isEditMode = signal(false);
  editingRestaurantId = signal<string | null>(null);
  error = signal('');
  loading = signal(false);

  cuisineOptions = ['Pizzeria', 'Ristorante', 'Pub', 'Paninoteca', 'Bar', 'Braceria', 'Enoteca', 'Sushi']; 
  
  constructor(
    private route: ActivatedRoute,
    private restaurantService: RestaurantService,
    private router: Router
  ) {}

  ngOnInit(): void {
    const restaurantId = this.route.snapshot.paramMap.get('id');
    if (!restaurantId) {
      return;
    }

    this.isEditMode.set(true);
    this.editingRestaurantId.set(restaurantId);
    this.loadRestaurantForEdit(restaurantId);
  }

  loadRestaurantForEdit(id: string): void {
    this.loading.set(true);
    this.error.set('');

    this.restaurantService.getRestaurant(id).subscribe({
      next: (response) => {
        const restaurant = response.restaurant;
        this.name.set(restaurant.name || '');
        this.description.set(restaurant.description || '');
        this.address.set(restaurant.address || '');
        this.cuisine.set(restaurant.cuisine || '');
        this.coverImageUrl.set(restaurant.coverImageUrl || '');
        this.loading.set(false);
      },
      error: (err) => {
        this.loading.set(false);
        this.error.set(err.error?.message || 'Caricamento del luogo fallito.');
      }
    });
  }

  onSubmit(): void {
    if (!this.name().trim()) {
      this.error.set('Il nome del luogo è obbligatorio.');
      return;
    }

    this.loading.set(true);
    this.error.set('');

    const data = {
      name: this.name().trim(),
      description: this.description().trim() || undefined,
      address: this.address().trim() || undefined,
      cuisine: this.cuisine().trim() || undefined,
      coverImageUrl: this.coverImageUrl().trim() || undefined
    };

    if (this.isEditMode()) {
      const restaurantId = this.editingRestaurantId();
      if (!restaurantId) {
        this.loading.set(false);
        this.error.set('ID del luogo non valido.');
        return;
      }

      this.restaurantService.updateRestaurant(restaurantId, data).subscribe({
        next: (response) => {
          this.router.navigate(['/restaurants', response.restaurant._id]);
        },
        error: (err) => {
          this.loading.set(false);
          this.error.set(err.error?.message || 'Aggiornamento del luogo fallito. Per favore riprova.');
        }
      });
      return;
    }

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

  getTitle(): string {
    return this.isEditMode() ? 'Modifica luogo' : 'Aggiungi luogo';
  }

  getSubtitle(): string {
    return this.isEditMode()
      ? 'Aggiorna i dati del luogo mantenendo invariate le recensioni esistenti.'
      : 'Crea un nuovo luogo compilando il form.';
  }

  getSubmitLabel(): string {
    return this.isEditMode() ? 'Aggiorna luogo' : 'Crea luogo';
  }

  getLoadingLabel(): string {
    return this.isEditMode() ? 'Aggiornamento in corso...' : 'Creazione in corso...';
  }

  getCancelRoute(): string[] {
    const restaurantId = this.editingRestaurantId();
    return this.isEditMode() && restaurantId ? ['/restaurants', restaurantId] : ['/restaurants'];
  }
}
