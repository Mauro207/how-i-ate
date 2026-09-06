import { Component, OnInit, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { RestaurantService, Restaurant } from '../../services/restaurant.service';
import { AuthService } from '../../services/auth.service';
import { NavigationComponent } from '../navigation/navigation.component';
import { RankingWidgetComponent } from '../ranking-widget/ranking-widget.component'; 
import { Title } from '@angular/platform-browser';
import { InviteComponent } from '../invite/invite.component';
import { LoadingIndicatorComponent } from '../loading-indicator/loading-indicator.component';

@Component({
  selector: 'app-restaurants',
  standalone: true,
  imports: [CommonModule, RouterLink, NavigationComponent, RankingWidgetComponent, InviteComponent, LoadingIndicatorComponent],
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
  private retryAttempted = false;

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
    this.error.set('');
    this.restaurantService.getRestaurants().subscribe({
      next: (restaurants) => {
        this.restaurants.set(restaurants);
        this.loading.set(false);
        this.retryAttempted = false;
      },
      error: (err) => {
        if (!this.retryAttempted && err.status === 0) {
          this.retryAttempted = true;
          setTimeout(() => this.loadRestaurants(), 2000);
        } else {
          this.error.set(this.httpErrorMessage(err, 'Caricamento dei luoghi fallito'));
          this.loading.set(false);
          this.retryAttempted = false;
        }
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

  private httpErrorMessage(err: any, context: string): string {
    if (err.status === 0) {
      return `${context}: impossibile raggiungere il server. Verifica la connessione e riprova.`;
    }
    if (err.status === 401) {
      return `${context}: sessione scaduta. Effettua nuovamente l'accesso.`;
    }
    if (err.status === 403) {
      return `${context}: accesso non autorizzato.`;
    }
    if (err.status === 404) {
      return `${context}: risorsa non trovata.`;
    }
    if (err.status === 429) {
      return `${context}: troppe richieste. Attendi qualche secondo e riprova.`;
    }
    if (err.status >= 500) {
      return `${context}: errore del server (${err.status}). Riprova più tardi.`;
    }
    return err.error?.message || `${context} (codice: ${err.status ?? 'nessuna risposta'}).`;
  }

  getCuisineIcon(cuisine?: string): string {
    const value = (cuisine || '').toLowerCase();
    if (value.includes('pizzeria')) return 'pizza';
    if (value.includes('enoteca')) return 'wine';
    if (value.includes('sushi')) return 'sushi';
    if (value.includes('paninoteca')) return 'burger';
    if (value.includes('bar')) return 'coffee';
    if (value.includes('gelateria') || value.includes('gelaterie')) return 'icecream';
    if (value.includes('pasticceria') || value.includes('pasticcerie')) return 'pastry';
    if (value.includes('dessert')) return 'dessert';
    return 'generic';
  }
}
