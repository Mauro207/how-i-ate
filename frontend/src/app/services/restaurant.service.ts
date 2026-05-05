import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable, of } from 'rxjs';
import { map, tap } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface Restaurant {
  _id: string;
  name: string;
  description?: string;
  address?: string;
  cuisine?: string;
  coverImageUrl?: string;
  googleMapsUrl?: string;
  instagramUrl?: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface Review {
  _id: string;
  restaurant: string;
  user: {
    _id: string;
    username: string;
    displayName?: string;
    email: string;
  };
  serviceRating: number;
  priceRating: number;
  menuRating: number;
  comment: string;
  createdAt: string;
  updatedAt: string;
}

export interface RankingItem {
  restaurantId: string;
  restaurantName: string;
  cuisine?: string;
  address?: string;
  averageRating: number;
  reviewCount: number;
}

export interface UserRankingItem {
  restaurantId: string;
  restaurantName: string;
  cuisine?: string;
  address?: string;
  averageRating: number;
  serviceRating: number;
  priceRating: number;
  menuRating: number;
  comment: string;
  createdAt: string;
  reviewCount: number;
}

export interface RestaurantSearchResult {
  _id: string;
  name: string;
  cuisine?: string;
  address?: string;
}

export interface Suggestion {
  _id: string;
  name: string;
  description?: string;
  address?: string;
  cuisine?: string;
  instagramUrl?: string;
  status: 'pending';
  suggestedBy: {
    _id: string;
    username: string;
    displayName?: string;
    email: string;
  };
  createdAt: string;
  updatedAt: string;
}

export interface FeedbackSummaryResponse {
  model: string;
  restaurantId: string;
  reviewCount: number;
  summary: string;
  generatedAt: string;
}

export interface GooglePlaceSuggestion {
  placeId: string;
  description: string;
  mainText: string;
  secondaryText: string;
}

export interface GooglePlaceDetails {
  placeId: string;
  name: string;
  city: string;
  mapsUrl: string;
}

@Injectable({
  providedIn: 'root'
})
export class RestaurantService {
  private apiUrl = environment.apiUrl;
  private http = inject(HttpClient);

  // Cache in-memory per il dettaglio ristorante (invalidata su update/delete)
  private restaurantCache = new Map<string, Restaurant>();

  /** Rimuove le voci correlate a un ristorante dalla CacheStorage del Service Worker. */
  private async invalidateSwCache(id: string): Promise<void> {
    if (!('caches' in window)) return;
    try {
      const cache = await caches.open('hia-api-v1');
      await Promise.all([
        cache.delete(`${this.apiUrl}/restaurants/${id}`),
        cache.delete(`${this.apiUrl}/reviews/restaurant/${id}`),
      ]);
    } catch {
      // Fallback silenzioso: il SW aggiornerà la cache alla prossima revalidazione
    }
  }

  getRestaurants(): Observable<Restaurant[]> {
    return this.http
      .get<{ count: number; restaurants: Restaurant[] }>(`${this.apiUrl}/restaurants`)
      .pipe(map(response => response.restaurants));
  }

  searchRestaurants(q: string): Observable<{ count: number; restaurants: RestaurantSearchResult[] }> {
    const params = new HttpParams().set('q', q);
    return this.http.get<{ count: number; restaurants: RestaurantSearchResult[] }>(
      `${environment.apiUrl}/restaurants/search`,
      { params }
    );
  }

  getGooglePlaceSuggestions(q: string): Observable<{ count: number; suggestions: GooglePlaceSuggestion[] }> {
    const params = new HttpParams().set('q', q);
    return this.http.get<{ count: number; suggestions: GooglePlaceSuggestion[] }>(
      `${this.apiUrl}/restaurants/places/autocomplete`,
      { params }
    );
  }

  getGooglePlaceDetails(placeId: string): Observable<GooglePlaceDetails> {
    const params = new HttpParams().set('placeId', placeId);
    return this.http.get<GooglePlaceDetails>(`${this.apiUrl}/restaurants/places/details`, { params });
  }

  getRestaurant(id: string): Observable<{ restaurant: Restaurant }> {
    const cached = this.restaurantCache.get(id);
    if (cached) {
      return of({ restaurant: cached });
    }
    return this.http
      .get<{ restaurant: Restaurant }>(`${this.apiUrl}/restaurants/${id}`)
      .pipe(tap((res) => this.restaurantCache.set(id, res.restaurant)));
  }

  createRestaurant(data: {
    name: string;
    description?: string;
    address?: string;
    cuisine?: string;
    coverImageUrl?: string;
    googleMapsUrl?: string;
    instagramUrl?: string;
  }): Observable<{ message: string; restaurant: Restaurant }> {
    return this.http.post<{ message: string; restaurant: Restaurant }>(
      `${this.apiUrl}/restaurants`,
      data
    );
  }

  updateRestaurant(id: string, data: Partial<Restaurant>): Observable<{ message: string; restaurant: Restaurant }> {
    return this.http
      .put<{ message: string; restaurant: Restaurant }>(`${this.apiUrl}/restaurants/${id}`, data)
      .pipe(tap((res) => {
        this.restaurantCache.set(id, res.restaurant);
        this.invalidateSwCache(id);
      }));
  }

  deleteRestaurant(id: string): Observable<{ message: string }> {
    return this.http
      .delete<{ message: string }>(`${this.apiUrl}/restaurants/${id}`)
      .pipe(tap(() => {
        this.restaurantCache.delete(id);
        this.invalidateSwCache(id);
      }));
  }

  getRestaurantReviews(restaurantId: string): Observable<{ count: number; reviews: Review[] }> {
    return this.http.get<{ count: number; reviews: Review[] }>(
      `${this.apiUrl}/reviews/restaurant/${restaurantId}`
    );
  }

  summarizeRestaurantFeedback(restaurantId: string): Observable<FeedbackSummaryResponse> {
    return this.http.post<FeedbackSummaryResponse>(
      `${this.apiUrl}/restaurants/${restaurantId}/feedback-summary`,
      {}
    );
  }

  createReview(restaurantId: string, data: {
    serviceRating: number;
    priceRating: number;
    menuRating: number;
    comment: string;
  }): Observable<{ message: string; review: Review }> {
    return this.http.post<{ message: string; review: Review }>(
      `${this.apiUrl}/reviews/restaurant/${restaurantId}`,
      data
    );
  }

  updateReview(reviewId: string, data: Partial<{
    serviceRating: number;
    priceRating: number;
    menuRating: number;
    comment: string;
  }>): Observable<{ message: string; review: Review }> {
    return this.http.put<{ message: string; review: Review }>(
      `${this.apiUrl}/reviews/${reviewId}`,
      data
    );
  }

  deleteReview(reviewId: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.apiUrl}/reviews/${reviewId}`);
  }

  // Get global restaurant rankings
  getGlobalRankings(): Observable<{ rankings: RankingItem[] }> {
    return this.http.get<{ rankings: RankingItem[] }>(`${this.apiUrl}/reviews/rankings/global`);
  }

  // Get user-specific restaurant rankings
  getUserRankings(userId: string): Observable<{ rankings: UserRankingItem[] }> {
    return this.http.get<{ rankings: UserRankingItem[] }>(`${this.apiUrl}/reviews/rankings/user/${userId}`);
  }

  // Suggestions
  createSuggestion(data: {
    name: string;
    description?: string;
    address?: string;
    cuisine?: string;
    instagramUrl?: string;
    review: {
      serviceRating: number;
      priceRating: number;
      menuRating: number;
      comment: string;
    };
  }): Observable<{ message: string; suggestion: Suggestion }> {
    return this.http.post<{ message: string; suggestion: Suggestion }>(
      `${this.apiUrl}/suggestions`,
      data
    );
  }

  getSuggestions(): Observable<{ count: number; suggestions: Suggestion[] }> {
    return this.http.get<{ count: number; suggestions: Suggestion[] }>(`${this.apiUrl}/suggestions`);
  }

  approveSuggestion(id: string): Observable<{ message: string; restaurant: Restaurant }> {
    return this.http.put<{ message: string; restaurant: Restaurant }>(
      `${this.apiUrl}/suggestions/${id}/approve`,
      {}
    );
  }

  rejectSuggestion(id: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.apiUrl}/suggestions/${id}`);
  }
}
