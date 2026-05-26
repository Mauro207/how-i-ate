import { Component, inject, signal, OnDestroy, OnInit, Input, Output, EventEmitter } from '@angular/core';
import { forkJoin, of, Subject } from 'rxjs';
import { catchError, debounceTime, distinctUntilChanged, map, switchMap, takeUntil, tap } from 'rxjs/operators';
import { RestaurantService, RestaurantSearchResult } from '../../services/restaurant.service';
import { AuthService, UserSearchResult } from '../../services/auth.service';
import { SuggestionsBadgeService } from '../../services/suggestions-badge.service';
import { RouterLink, Router } from '@angular/router';
import { CommonModule, NgIf } from '@angular/common';
import { Location } from '@angular/common';
import { FormsModule } from '@angular/forms';

type SearchItem =
  | { type: 'restaurant'; id: string; title: string; subtitle?: string }
  | { type: 'user'; id: string; title: string; subtitle?: string };

@Component({
  selector: 'app-navigation',
  templateUrl: './navigation.component.html',
  styleUrls: ['./navigation.component.css'],
  imports: [ RouterLink, CommonModule, FormsModule, NgIf ] 
})
export class NavigationComponent implements OnInit, OnDestroy {
  menuOpen = false;
  showSearchDropdown = signal(false);

  @Input() backUrl: string | null = null;
  @Input() useHistoryBack = false;
  @Input() showEditBtn = false;
  @Input() showDeleteBtn = false;
  @Output() editClicked = new EventEmitter<void>();
  @Output() deleteClicked = new EventEmitter<void>();
  showMobileSearch = signal(false);
  searchQuery = signal('');

  // usa SOLO questi nel template
  results = signal<SearchItem[]>([]);
  searching = signal(false);

  private readonly restaurantService = inject(RestaurantService);
  public readonly authService = inject(AuthService);
  public readonly suggestionsBadgeService = inject(SuggestionsBadgeService);
  private readonly router = inject(Router);
  private readonly location = inject(Location);

  private readonly destroy$ = new Subject<void>();
  private readonly searchInput$ = new Subject<string>();

  constructor() {
    this.searchInput$
      .pipe(
        map(q => (q || '').trim()),
        tap(q => {
          this.searchQuery.set(q);
          if (!q) {
            this.results.set([]);
            this.searching.set(false);
          }
        }),
        debounceTime(250),
        distinctUntilChanged(),
        switchMap(query => {
          if (!query) return of([] as SearchItem[]);
          this.searching.set(true);

          return forkJoin({
            restaurants: this.restaurantService
              .searchRestaurants(query)
              .pipe(catchError(() => of({ count: 0, restaurants: [] as RestaurantSearchResult[] }))),

            users: this.authService
              .searchUsers(query)
              .pipe(catchError(() => of({ count: 0, users: [] as UserSearchResult[] })))
          }).pipe(
            map(({ restaurants, users }) => {
              const rItems: SearchItem[] = restaurants.restaurants.map(r => ({
                type: 'restaurant',
                id: r._id,
                title: r.name,
                subtitle: [r.cuisine, r.address].filter(Boolean).join(' • ') || undefined
              }));

              const uItems: SearchItem[] = users.users.map(u => ({
                type: 'user',
                id: u._id,
                title: u.displayName?.trim() ? u.displayName : u.username,
                subtitle: `@${u.username}`
              }));

              return [...rItems, ...uItems];
            }),
            tap(() => this.searching.set(false)),
            catchError(() => {
              this.searching.set(false);
              return of([] as SearchItem[]);
            })
          );
        }),
        takeUntil(this.destroy$)
      )
      .subscribe(items => this.results.set(items));
  }

  ngOnInit(): void {
    this.suggestionsBadgeService.refreshPendingCount();
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }

  logout() {
    this.authService.logout();
  }

  isActive(url: string): boolean {
    return this.router.url === url; 
  }

  isRoutePrefixActive(prefix: string): boolean {
    return this.router.url.startsWith(prefix);
  }

  toggleMenu(): void {
    this.menuOpen = !this.menuOpen; 
    if (this.menuOpen) {
      this.suggestionsBadgeService.refreshPendingCount();
    }
  }

  onBackClick(): void {
    if (this.useHistoryBack && typeof window !== 'undefined' && window.history.length > 1) {
      this.location.back();
      return;
    }

    if (this.backUrl) {
      this.router.navigateByUrl(this.backUrl);
      return;
    }

    this.router.navigate(['/restaurants']);
  }

  goToMyRankings(): void {
    const user = this.authService.currentUser();
    if (!user) {
      this.router.navigate(['/login']);
      return;
    }

    const userId = user.id;
    const username = user.username || 'Utente';
    this.router.navigate(['/profile', userId, username]);
  }

  onSearchInputChange(event: Event): void {
    const value = (event.target as HTMLInputElement)?.value ?? '';
    this.showSearchDropdown.set(true);
    this.searchInput$.next(value);
  }

  closeSearch(): void {
    this.showSearchDropdown.set(false);
  }

  toggleMobileSearch(): void {
    this.showMobileSearch.set(!this.showMobileSearch());
    if (!this.showMobileSearch()) {
      this.searchQuery.set('');
      this.results.set([]);
      this.showSearchDropdown.set(false);
    }
  }

  goToResult(item: SearchItem) {
    this.searchQuery.set('');
    this.results.set([]);
    this.showSearchDropdown.set(false);

    if (item.type === 'restaurant') {
      this.router.navigate(['/restaurants', item.id]);
      return;
    }

    // Vai al profilo dell'utente (passa anche username per header frontend)
    const username = item.subtitle?.startsWith('@') ? item.subtitle.slice(1) : undefined;
    if (username) {
      this.router.navigate(['/profile', item.id, username]);
      return;
    }

    this.router.navigate(['/profile', item.id]);
  }

  isSuperAdmin(): boolean {
    return this.authService.currentUser()?.role === 'superadmin';
  }

  isAdminOrSuperAdmin(): boolean {
    const role = this.authService.currentUser()?.role;
    return role === 'admin' || role === 'superadmin';
  }

  pendingSuggestionsCount(): number {
    return this.suggestionsBadgeService.pendingCount();
  }
}
