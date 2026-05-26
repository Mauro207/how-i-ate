import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { RestaurantService, Restaurant, Review } from '../../services/restaurant.service';
import { AuthService } from '../../services/auth.service';
import { NavigationComponent } from '../navigation/navigation.component';

@Component({
  selector: 'app-restaurant-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, NavigationComponent],
  templateUrl: './restaurant-detail.component.html',
  styleUrl: './restaurant-detail.component.css'
})
export class RestaurantDetailComponent implements OnInit {
  restaurant = signal<Restaurant | null>(null);
  reviews = signal<Review[]>([]);
  reviewsLoading = signal(true);
  reviewAccordionOpen = signal<Record<string, boolean>>({});
  reviewActionsMenuOpen = signal<Record<string, boolean>>({});
  coverImageLoadFailed = signal(false);
  loading = signal(true);
  error = signal('');
  reviewsError = signal('');
  private retryAttempted = false;
  private reviewsRetryAttempted = false;
  feedbackSummary = signal('');
  feedbackSummaryError = signal('');
  feedbackSummaryLoading = signal(false);
  
  // Review form constants
  private readonly DEFAULT_RATING = 5;
  readonly MIN_RATING = 0.25;
  readonly MAX_RATING = 10;
  readonly RATING_STEP = 0.25;
  readonly COMMENT_MIN_LENGTH = 5;
  readonly COMMENT_MAX_LENGTH = 600;
  
  // Review form
  showReviewForm = signal(false);
  serviceRating = signal(this.DEFAULT_RATING);
  priceRating = signal(this.DEFAULT_RATING);
  menuRating = signal(this.DEFAULT_RATING);
  comment = signal('');
  submittingReview = signal(false);
  reviewError = signal('');

  // Edit review
  editingReviewId = signal<string | null>(null);
  deletingReviewId = signal<string | null>(null);
  deletingRestaurant = signal(false);

  constructor(
    private route: ActivatedRoute,
    private router: Router,
    private restaurantService: RestaurantService,
    public authService: AuthService
  ) {}

  ngOnInit(): void {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) {
      this.loadRestaurant(id);
      this.loadReviews(id);
    }
  }

  reloadRestaurant(): void {
    const id = this.route.snapshot.paramMap.get('id');
    if (id) this.loadRestaurant(id);
  }

  reloadReviews(): void {
    const id = this.restaurant()?._id ?? this.route.snapshot.paramMap.get('id');
    if (id) this.loadReviews(id);
  }

  loadRestaurant(id: string): void {
    this.loading.set(true);
    this.error.set('');
    this.restaurantService.getRestaurant(id).subscribe({
      next: (response) => {
        this.restaurant.set(response.restaurant);
        this.coverImageLoadFailed.set(false);
        this.loading.set(false);
        this.retryAttempted = false;
      },
      error: (err) => {
        if (!this.retryAttempted && err.status === 0) {
          this.retryAttempted = true;
          setTimeout(() => this.loadRestaurant(id), 2000);
        } else {
          this.error.set(this.httpErrorMessage(err, 'Caricamento del luogo fallito'));
          this.loading.set(false);
          this.retryAttempted = false;
        }
      }
    });
  }

  onCoverImageError(): void {
    this.coverImageLoadFailed.set(true);
  }

  loadReviews(id: string): void {
    this.reviewsLoading.set(true);
    this.reviewsError.set('');
    this.restaurantService.getRestaurantReviews(id).subscribe({
      next: (response) => {
        this.reviews.set(response.reviews);
        this.reviewsLoading.set(false);
        this.reviewsRetryAttempted = false;
      },
      error: (err) => {
        if (!this.reviewsRetryAttempted && err.status === 0) {
          this.reviewsRetryAttempted = true;
          setTimeout(() => this.loadReviews(id), 2000);
        } else {
          this.reviewsError.set(this.httpErrorMessage(err, 'Caricamento delle recensioni fallito'));
          this.reviewsLoading.set(false);
          this.reviewsRetryAttempted = false;
        }
      }
    });
  }

  summarizeFeedback(): void {
    const restaurantId = this.restaurant()?._id;
    if (!restaurantId) {
      return;
    }

    this.feedbackSummaryLoading.set(true);
    this.feedbackSummaryError.set('');

    this.restaurantService.summarizeRestaurantFeedback(restaurantId).subscribe({
      next: (response) => {
        this.feedbackSummary.set(response.summary);
        this.feedbackSummaryLoading.set(false);
      },
      error: (err) => {
        this.feedbackSummaryLoading.set(false);
        this.feedbackSummaryError.set(
          err?.error?.message || 'Riassunto feedback non disponibile al momento.'
        );
      }
    });
  }

  toggleReviewForm(): void {
    this.showReviewForm.set(!this.showReviewForm());
    if (this.showReviewForm()) {
      this.reviewError.set('');
    }
  }

  toggleReviewAccordion(reviewId: string): void {
    const current = this.reviewAccordionOpen();
    this.reviewAccordionOpen.set({
      ...current,
      [reviewId]: !current[reviewId]
    });
  }

  isReviewAccordionOpen(reviewId: string): boolean {
    return !!this.reviewAccordionOpen()[reviewId];
  }

  toggleReviewActionsMenu(reviewId: string): void {
    const current = this.reviewActionsMenuOpen();
    this.reviewActionsMenuOpen.set({
      ...current,
      [reviewId]: !current[reviewId]
    });
  }

  isReviewActionsMenuOpen(reviewId: string): boolean {
    return !!this.reviewActionsMenuOpen()[reviewId];
  }

  isAdminOrSuperadmin(): boolean {
    const user = this.authService.currentUser();
    return !!user && (user.role === 'admin' || user.role === 'superadmin');
  }

  isOwnReview(review: Review): boolean {
    const user = this.authService.currentUser();
    return !!user && review.user._id === user.id;
  }

  submitReview(): void {
    if (this.editingReviewId()) {
      this.updateReview();
    } else {
      this.createReview();
    }
  }

  createReview(): void {
    const trimmed = this.comment().trim();
    if (!trimmed) {
      this.reviewError.set('Per favore aggiungi un commento.');
      return;
    }
    if (trimmed.length < this.COMMENT_MIN_LENGTH) {
      this.reviewError.set(`Il commento deve essere di almeno ${this.COMMENT_MIN_LENGTH} caratteri.`);
      return;
    }
    if (trimmed.length > this.COMMENT_MAX_LENGTH) {
      this.reviewError.set(`Il commento supera il limite di ${this.COMMENT_MAX_LENGTH} caratteri (${trimmed.length}/${this.COMMENT_MAX_LENGTH}).`);
      return;
    }

    const restaurantId = this.restaurant()?._id;
    if (!restaurantId) return;

    this.submittingReview.set(true);
    this.reviewError.set('');

    const reviewData = {
      serviceRating: this.serviceRating(),
      priceRating: this.priceRating(),
      menuRating: this.menuRating(),
      comment: this.comment()
    };

    this.restaurantService.createReview(restaurantId, reviewData).subscribe({
      next: () => {
        this.submittingReview.set(false);
        this.showReviewForm.set(false);
        this.resetReviewForm();
        this.loadReviews(restaurantId);
      },
      error: (err) => {
        this.submittingReview.set(false);
        this.reviewError.set(err.error?.message || 'Creazione della recensione fallita');
      }
    });
  }

  resetReviewForm(): void {
    this.serviceRating.set(this.DEFAULT_RATING);
    this.priceRating.set(this.DEFAULT_RATING);
    this.menuRating.set(this.DEFAULT_RATING);
    this.comment.set('');
    this.reviewError.set('');
  }

  calculateAverageRating(review: Review): number {
    return (review.serviceRating + review.priceRating + review.menuRating) / 3;
  }

  formatRating(rating: number): string {
    // Round to nearest 0.25 to align with slider steps and consistent display
    const rounded = Math.round(rating * 4) / 4;
    const whole = Math.floor(rounded);
    const remainder = +(rounded - whole).toFixed(2);

    if (remainder === 0.25) return `${whole}+`;
    if (remainder === 0.75) return `${whole + 1}-`;

    // Keep .0 and .5 as standard decimals
    return rounded.toFixed(1);
  }

  formatReviewDate(value: string | Date): string {
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) {
      return '';
    }

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const targetDay = new Date(date.getFullYear(), date.getMonth(), date.getDate());
    const dayDiff = Math.round((today.getTime() - targetDay.getTime()) / 86400000);
    const time = date.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });

    if (dayDiff === 0) {
      return `Oggi, ${time}`;
    }
    if (dayDiff === 1) {
      return `Ieri, ${time}`;
    }
    if (dayDiff === 2) {
      return `L'altro ieri, ${time}`;
    }

    const pad2 = (n: number) => n.toString().padStart(2, '0');
    const dd = pad2(date.getDate());
    const mm = pad2(date.getMonth() + 1);
    const yy = pad2(date.getFullYear() % 100);
    const hh = pad2(date.getHours());
    const min = pad2(date.getMinutes());

    return `${dd}/${mm}/${yy}, ${hh}:${min}`;
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

  viewUserRankings(userId: string, username: string): void {
    this.router.navigate(['/user-rankings', userId, username]);
  }

  canEditReview(review: Review): boolean {
    const user = this.authService.currentUser();
    if (!user) return false;
    return review.user._id === user.id || user.role === 'admin' || user.role === 'superadmin';
  }

  canDeleteReview(review: Review): boolean {
    return this.canEditReview(review);
  }

  editReview(review: Review): void {
    this.reviewActionsMenuOpen.set({
      ...this.reviewActionsMenuOpen(),
      [review._id]: false
    });
    this.editingReviewId.set(review._id);
    this.serviceRating.set(review.serviceRating);
    this.priceRating.set(review.priceRating);
    this.menuRating.set(review.menuRating);
    this.comment.set(review.comment);
    this.showReviewForm.set(true);
    this.reviewError.set('');
  }

  cancelEdit(): void {
    this.editingReviewId.set(null);
    this.resetReviewForm();
    this.showReviewForm.set(false);
  }

  getRestaurantAverageRating(): number | null {
    const all = this.reviews();
    if (!all.length) return null;
    const total = all.reduce((sum, review) => sum + this.calculateAverageRating(review), 0);
    return total / all.length;
  }

  updateReview(): void {
    const trimmed = this.comment().trim();
    if (!trimmed) {
      this.reviewError.set('Aggiornamento della recensione fallita: aggiungi un commento');
      return;
    }
    if (trimmed.length < this.COMMENT_MIN_LENGTH) {
      this.reviewError.set(`Il commento deve essere di almeno ${this.COMMENT_MIN_LENGTH} caratteri.`);
      return;
    }
    if (trimmed.length > this.COMMENT_MAX_LENGTH) {
      this.reviewError.set(`Il commento supera il limite di ${this.COMMENT_MAX_LENGTH} caratteri (${trimmed.length}/${this.COMMENT_MAX_LENGTH}).`);
      return;
    }

    const reviewId = this.editingReviewId();
    if (!reviewId) return;

    this.submittingReview.set(true);
    this.reviewError.set('');

    const reviewData = {
      serviceRating: this.serviceRating(),
      priceRating: this.priceRating(),
      menuRating: this.menuRating(),
      comment: this.comment()
    };

    this.restaurantService.updateReview(reviewId, reviewData).subscribe({
      next: () => {
        this.submittingReview.set(false);
        this.editingReviewId.set(null);
        this.showReviewForm.set(false);
        this.resetReviewForm();
        const restaurantId = this.restaurant()?._id;
        if (restaurantId) {
          this.loadReviews(restaurantId);
        }
      },
      error: (err) => {
        this.submittingReview.set(false);
        this.reviewError.set(err.error?.message || 'Aggiornamento della recensione fallita');
      }
    });
  }

  deleteReview(reviewId: string): void {
    this.reviewActionsMenuOpen.set({
      ...this.reviewActionsMenuOpen(),
      [reviewId]: false
    });

    if (!confirm('Confermi di voler cancellare questa recensione?')) {
      return;
    }

    this.deletingReviewId.set(reviewId);

    this.restaurantService.deleteReview(reviewId).subscribe({
      next: () => {
        this.deletingReviewId.set(null);
        const restaurantId = this.restaurant()?._id;
        if (restaurantId) {
          this.loadReviews(restaurantId);
        }
      },
      error: (err) => {
        this.deletingReviewId.set(null);
        alert(err.error?.message || 'Cancellazione della recensione fallita');
      }
    });
  }

  getUserDisplayName(review: Review): string {
    return review.user.displayName || review.user.username;
  }

  hasUserReviewed(): boolean {
    const user = this.authService.currentUser();
    if (!user) return false;
    return this.reviews().some(review => review.user._id === user.id);
  }

  canDeleteRestaurant(): boolean {
    const user = this.authService.currentUser();
    const restaurant = this.restaurant();
    if (!user || !restaurant) return false;
    
    const isCreator = restaurant.createdBy === user.id;
    const isAdminOrSuperadmin = user.role === 'admin' || user.role === 'superadmin';
    
    return isCreator || isAdminOrSuperadmin;
  }

  canEditRestaurant(): boolean {
    const user = this.authService.currentUser();
    if (!user) return false;

    return user.role === 'admin' || user.role === 'superadmin';
  }

  editRestaurant(): void {
    const restaurant = this.restaurant();
    if (!restaurant) return;

    this.router.navigate(['/restaurants', restaurant._id, 'edit']);
  }

  deleteRestaurant(): void {
    const restaurant = this.restaurant();
    if (!restaurant) return;

    if (!confirm(`Sei sicuro di voler eliminare "${restaurant.name}"? Questa azione non può essere annullata.`)) {
      return;
    }

    this.deletingRestaurant.set(true);

    this.restaurantService.deleteRestaurant(restaurant._id).subscribe({
      next: () => {
        this.router.navigate(['/restaurants']);
      },
      error: (err) => {
        this.deletingRestaurant.set(false);
        alert(err.error?.message || 'Cancellazione del ristorante fallita');
      }
    });
  }
}
