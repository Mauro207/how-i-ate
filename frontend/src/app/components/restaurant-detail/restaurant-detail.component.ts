import { Component, OnInit, signal } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { RestaurantService, Restaurant, Review } from '../../services/restaurant.service';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-restaurant-detail',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './restaurant-detail.component.html',
  styleUrl: './restaurant-detail.component.css'
})
export class RestaurantDetailComponent implements OnInit {
  restaurant = signal<Restaurant | null>(null);
  reviews = signal<Review[]>([]);
  loading = signal(true);
  error = signal('');
  
  // Review form constants
  private readonly DEFAULT_RATING = 3;
  readonly MIN_RATING = 1;
  readonly MAX_RATING = 5;
  readonly RATING_STEP = 0.1;
  
  // Review form
  showReviewForm = signal(false);
  serviceRating = signal(this.DEFAULT_RATING);
  priceRating = signal(this.DEFAULT_RATING);
  menuRating = signal(this.DEFAULT_RATING);
  comment = signal('');
  submittingReview = signal(false);
  reviewError = signal('');

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
        this.error.set('Failed to load restaurant');
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
        console.error('Failed to load reviews', err);
      }
    });
  }

  toggleReviewForm(): void {
    this.showReviewForm.set(!this.showReviewForm());
    if (this.showReviewForm()) {
      this.reviewError.set('');
    }
  }

  submitReview(): void {
    if (!this.comment().trim()) {
      this.reviewError.set('Please provide a comment');
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
        this.reviewError.set(err.error?.message || 'Failed to submit review');
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
    return rating.toFixed(1);
  }

  viewUserRankings(userId: string, username: string): void {
    this.router.navigate(['/user-rankings', userId, username]);
  }
}
