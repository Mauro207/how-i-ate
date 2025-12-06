import { Component, signal } from '@angular/core';
import { AuthService } from '../../services/auth.service';
import { RestaurantService } from '../../services/restaurant.service';
import { RouterLink, Router } from '@angular/router';
import { CommonModule, NgIf } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-navigation',
  templateUrl: './navigation.component.html',
  styleUrls: ['./navigation.component.css'],
  imports: [ RouterLink, CommonModule, FormsModule, NgIf ] 
})
export class NavigationComponent {
  menuOpen = false;
  showSearchDropdown = signal(false);
  searchQuery = signal('');
  searchResults = signal<any[]>([]);
  isSearching = signal(false);

  constructor(
    public authService: AuthService,
    private router: Router,
    private restaurantService: RestaurantService
  ) {}

  logout() {
    this.authService.logout();
  }

  isActive(url: string): boolean {
    return this.router.url === url; 
  }

  toggleMenu(): void {
    this.menuOpen = !this.menuOpen; 
  }

  goToMyRankings(): void {
    const user = this.authService.currentUser();
    if (!user) {
      this.router.navigate(['/login']);
      return;
    }

    const userId = user.id;
    const username = user.username || 'Utente';
    this.router.navigate(['/user-rankings', userId, username]);
  }

  onSearchInputChange(event: any): void {
    const query = event.target.value;
    this.searchQuery.set(query);
    
    if (!query.trim()) {
      this.searchResults.set([]);
      this.showSearchDropdown.set(false);
      return;
    }

    this.isSearching.set(true);
    this.showSearchDropdown.set(true);

    this.restaurantService.searchRestaurants(query).subscribe({
      next: (results) => {
        console.log('Risultati ricerca:', results);
        this.searchResults.set(results.slice(0, 5));
        this.isSearching.set(false);
      },
      error: (err) => {
        console.error('Errore nella ricerca:', err);
        this.searchResults.set([]);
        this.isSearching.set(false);
      }
    });
  }

  selectRestaurant(restaurantId: string): void {
    this.searchQuery.set('');
    this.searchResults.set([]);
    this.showSearchDropdown.set(false);
    this.router.navigate(['/restaurants', restaurantId]);
  }

  closeSearch(): void {
    this.showSearchDropdown.set(false);
  }
}