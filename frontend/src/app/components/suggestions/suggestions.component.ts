import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { RestaurantService, Suggestion } from '../../services/restaurant.service';
import { NavigationComponent } from '../navigation/navigation.component';
import { Title } from '@angular/platform-browser';
import { SuggestionsBadgeService } from '../../services/suggestions-badge.service';

@Component({
  selector: 'app-suggestions',
  standalone: true,
  imports: [CommonModule, NavigationComponent],
  templateUrl: './suggestions.component.html',
  styleUrl: './suggestions.component.css'
})
export class SuggestionsComponent implements OnInit {
  suggestions = signal<Suggestion[]>([]);
  loading = signal(true);
  error = signal('');
  actionLoading = signal<string | null>(null);

  constructor(
    private restaurantService: RestaurantService,
    private suggestionsBadgeService: SuggestionsBadgeService,
    private router: Router,
    private title: Title
  ) {}

  ngOnInit(): void {
    this.title.setTitle('Suggerimenti - How I Ate');
    this.suggestionsBadgeService.refreshPendingCount(true);
    this.loadSuggestions();
  }

  loadSuggestions(): void {
    this.loading.set(true);
    this.error.set('');
    this.restaurantService.getSuggestions().subscribe({
      next: (resp) => {
        this.suggestions.set(resp.suggestions);
        this.suggestionsBadgeService.setPendingCount(resp.count || 0);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Errore nel caricamento dei suggerimenti.');
        this.loading.set(false);
      }
    });
  }

  approve(id: string): void {
    this.actionLoading.set(id);
    this.restaurantService.approveSuggestion(id).subscribe({
      next: (resp) => {
        this.suggestions.set(this.suggestions().filter(s => s._id !== id));
        this.suggestionsBadgeService.setPendingCount(this.suggestions().length);
        this.actionLoading.set(null);
        this.router.navigate(['/restaurants', resp.restaurant._id]);
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Errore nell\'approvazione del suggerimento.');
        this.actionLoading.set(null);
      }
    });
  }

  reject(id: string): void {
    this.actionLoading.set(id);
    this.restaurantService.rejectSuggestion(id).subscribe({
      next: () => {
        this.suggestions.set(this.suggestions().filter(s => s._id !== id));
        this.suggestionsBadgeService.setPendingCount(this.suggestions().length);
        this.actionLoading.set(null);
      },
      error: (err) => {
        this.error.set(err.error?.message || 'Errore nel rifiuto del suggerimento.');
        this.actionLoading.set(null);
      }
    });
  }

  getSuggestedByName(suggestion: Suggestion): string {
    const u = suggestion.suggestedBy;
    return u.displayName?.trim() ? u.displayName : u.username;
  }
}
