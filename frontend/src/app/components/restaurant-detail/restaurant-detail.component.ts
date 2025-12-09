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
  reviewAccordionOpen = signal<Record<string, boolean>>({});
  loading = signal(true);
  error = signal('');
  
  // Review form constants
  private readonly DEFAULT_RATING = 5;
  readonly MIN_RATING = 0.25;
  readonly MAX_RATING = 10;
  readonly RATING_STEP = 0.25;
  
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

  loadRestaurant(id: string): void {
    this.restaurantService.getRestaurant(id).subscribe({
      next: (response) => {
        this.restaurant.set(response.restaurant);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set('Caricamento del luogo fallito.');
        this.loading.set(false);
      }
    });
  }

  loadReviews(id: string): void {
    this.restaurantService.getRestaurantReviews(id).subscribe({
      next: (response) => {
        this.reviews.set(response.reviews);
      },
      error: (err) => {
        console.error('Caricamento del luogo fallito.', err);
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

  submitReview(): void {
    if (this.editingReviewId()) {
      this.updateReview();
    } else {
      this.createReview();
    }
  }

  createReview(): void {
    if (!this.comment().trim()) {
      this.reviewError.set('Per favore aggiungi un commento.');
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

  updateReview(): void {
    if (!this.comment().trim()) {
      this.reviewError.set('Aggiornamento della recensione fallita: aggiungi un commento');
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
