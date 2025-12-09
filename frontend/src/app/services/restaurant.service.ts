import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { environment } from '../../environments/environment';

export interface Restaurant {
  _id: string;
  name: string;
  description?: string;
  address?: string;
  cuisine?: string;
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

@Injectable({
  providedIn: 'root'
})
export class RestaurantService {
  private apiUrl = environment.apiUrl;

  constructor(private http: HttpClient) {}

  getRestaurants(): Observable<Restaurant[]> {
    return this.http.get<{ count: number; restaurants: Restaurant[] }>(`${this.apiUrl}/restaurants`)
      .pipe(map(response => response.restaurants));
  }

  searchRestaurants(query?: string, cuisine?: string): Observable<Restaurant[]> {
    let params = '';
    if (query) {
      params += `?q=${encodeURIComponent(query)}`;
    }
    if (cuisine) {
      params += (params ? '&' : '?') + `cuisine=${encodeURIComponent(cuisine)}`;
    }
    
    return this.http.get<{ count: number; restaurants: Restaurant[] }>(
      `${this.apiUrl}/restaurants/search${params}`
    ).pipe(map(response => response.restaurants));
  }

  getRestaurant(id: string): Observable<{ restaurant: Restaurant }> {
    return this.http.get<{ restaurant: Restaurant }>(`${this.apiUrl}/restaurants/${id}`);
  }

  createRestaurant(data: {
    name: string;
    description?: string;
    address?: string;
    cuisine?: string;
  }): Observable<{ message: string; restaurant: Restaurant }> {
    return this.http.post<{ message: string; restaurant: Restaurant }>(
      `${this.apiUrl}/restaurants`,
      data
    );
  }

  updateRestaurant(id: string, data: Partial<Restaurant>): Observable<{ message: string; restaurant: Restaurant }> {
    return this.http.put<{ message: string; restaurant: Restaurant }>(
      `${this.apiUrl}/restaurants/${id}`,
      data
    );
  }

  deleteRestaurant(id: string): Observable<{ message: string }> {
    return this.http.delete<{ message: string }>(`${this.apiUrl}/restaurants/${id}`);
  }

  getRestaurantReviews(restaurantId: string): Observable<{ count: number; reviews: Review[] }> {
    return this.http.get<{ count: number; reviews: Review[] }>(
      `${this.apiUrl}/reviews/restaurant/${restaurantId}`
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
}
