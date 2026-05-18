import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { forkJoin, of } from 'rxjs';
import { catchError, debounceTime, distinctUntilChanged, map, switchMap, tap } from 'rxjs/operators';
import { Subject } from 'rxjs';
import { NavigationComponent } from '../navigation/navigation.component';
import { RestaurantService, Restaurant, RestaurantSearchResult } from '../../services/restaurant.service';
import { AuthService, UserSearchResult } from '../../services/auth.service';

type SearchResultItem =
  | { type: 'restaurant'; id: string; title: string; subtitle?: string }
  | { type: 'user'; id: string; title: string; subtitle?: string };

@Component({
  selector: 'app-search',
  standalone: true,
  imports: [CommonModule, FormsModule, NavigationComponent],
  templateUrl: './search.component.html',
  styleUrl: './search.component.css'
})
export class SearchComponent implements OnInit {
  query = signal('');
  loading = signal(false);
  searchResults = signal<SearchResultItem[]>([]);
  randomRestaurants = signal<Restaurant[]>([]);
  totalRestaurants = signal(0);

  private readonly queryInput$ = new Subject<string>();
  private readonly restaurantService = inject(RestaurantService);
  private readonly authService = inject(AuthService);
  private readonly router = inject(Router);

  hasQuery = computed(() => this.query().trim().length > 0);

  ngOnInit(): void {
    this.loadDefaultSections();

    this.queryInput$
      .pipe(
        map(value => value.trim()),
        tap(value => {
          this.query.set(value);
          if (!value) {
            this.searchResults.set([]);
            this.loading.set(false);
          }
        }),
        debounceTime(250),
        distinctUntilChanged(),
        switchMap(value => {
          if (!value) {
            return of([] as SearchResultItem[]);
          }

          this.loading.set(true);

          return forkJoin({
            restaurants: this.restaurantService
              .searchRestaurants(value)
              .pipe(catchError(() => of({ count: 0, restaurants: [] as RestaurantSearchResult[] }))),
            users: this.authService
              .searchUsers(value)
              .pipe(catchError(() => of({ count: 0, users: [] as UserSearchResult[] })))
          }).pipe(
            map(({ restaurants, users }) => {
              const restaurantItems: SearchResultItem[] = restaurants.restaurants.map(r => ({
                type: 'restaurant',
                id: r._id,
                title: r.name,
                subtitle: [r.cuisine, r.address].filter(Boolean).join(' • ') || undefined
              }));

              const userItems: SearchResultItem[] = users.users.map(u => ({
                type: 'user',
                id: u._id,
                title: u.displayName?.trim() ? u.displayName : u.username,
                subtitle: `@${u.username}`
              }));

              return [...restaurantItems, ...userItems];
            }),
            tap(() => this.loading.set(false)),
            catchError(() => {
              this.loading.set(false);
              return of([] as SearchResultItem[]);
            })
          );
        })
      )
      .subscribe(items => this.searchResults.set(items));
  }

  onQueryChange(event: Event): void {
    const value = (event.target as HTMLInputElement)?.value ?? '';
    this.queryInput$.next(value);
  }

  openResult(item: SearchResultItem): void {
    if (item.type === 'restaurant') {
      this.router.navigate(['/restaurants', item.id]);
      return;
    }

    const username = item.subtitle?.startsWith('@') ? item.subtitle.slice(1) : undefined;
    if (username) {
      this.router.navigate(['/user-rankings', item.id, username]);
      return;
    }

    this.router.navigate(['/user-rankings', item.id]);
  }

  openRestaurant(id: string): void {
    this.router.navigate(['/restaurants', id]);
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

  formatRestaurantSubtitle(restaurant: Restaurant): string {
    const parts = [restaurant.cuisine, restaurant.address].filter(
      (value): value is string => Boolean(value)
    );
    return parts.join(' • ') || 'Dettagli non disponibili';
  }

  trackBySearchItem(_index: number, item: SearchResultItem): string {
    return `${item.type}-${item.id}`;
  }

  private loadDefaultSections(): void {
    this.restaurantService.getRestaurants().subscribe({
      next: restaurants => {
        this.totalRestaurants.set(restaurants.length);
        const shuffled = [...restaurants]
          .sort(() => Math.random() - 0.5)
          .slice(0, 5);
        this.randomRestaurants.set(shuffled);
      },
      error: () => {
        this.totalRestaurants.set(0);
        this.randomRestaurants.set([]);
      }
    });
  }
}
