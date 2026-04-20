import { Injectable, signal, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { timeout } from 'rxjs/operators';
import { environment } from '../../environments/environment';
import { TokenStorageService } from './token-storage.service';

export interface User {
  id: string;
  username: string;
  displayName?: string;
  email: string;
  role: string;
}

export interface LoginResponse {
  message: string;
  token: string;
  user: User;
}

export interface UserSearchResult {
  _id: string;
  username: string;
  displayName?: string;
  role: 'user' | 'admin' | 'superadmin';
  createdAt?: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = `${environment.apiUrl}/auth`;
  private http = inject(HttpClient);
  private tokenStorage = inject(TokenStorageService);

  currentUser = signal<User | null>(null);
  isAuthenticated = signal<boolean>(false);

  private authInitialized$ = new BehaviorSubject<boolean>(false);

  // This BehaviorSubject does not need to be completed: AuthService is a root-level
  // singleton that lives for the entire application lifetime and is never destroyed.
  get authInitialized(): Observable<boolean> {
    return this.authInitialized$.asObservable();
  }

  constructor(private httpClient: HttpClient, private router: Router) {
    this.loadUserFromToken();
  }

  login(email: string, password: string): Observable<LoginResponse> {
    return this.httpClient.post<LoginResponse>(`${this.apiUrl}/login`, { email, password })
      .pipe(
        tap(response => {
          this.tokenStorage.setToken(response.token);
          this.currentUser.set(response.user);
          this.isAuthenticated.set(true);
        })
      );
  }

  register(username: string, email: string, password: string): Observable<any> {
    return this.httpClient.post(`${this.apiUrl}/register`, { username, email, password });
  }

  createUser(username: string, email: string, password: string): Observable<any> {
    return this.httpClient.post(`${this.apiUrl}/create-user`, { username, email, password });
  }

  createAdmin(username: string, email: string, password: string): Observable<any> {
    return this.httpClient.post(`${this.apiUrl}/create-admin`, { username, email, password });
  }

  updateProfile(displayName: string): Observable<any> {
    return this.httpClient.put<{ message: string; user: User }>(`${this.apiUrl}/profile`, { displayName })
      .pipe(
        tap(response => {
          this.currentUser.set(response.user);
        })
      );
  }

  getAllUsers(): Observable<{ users: User[] }> {
    return this.httpClient.get<{ users: User[] }>(`${this.apiUrl}/users`);
  }

  updateUserPassword(userId: string, password: string): Observable<{ message: string }> {
    return this.httpClient.put<{ message: string }>(`${this.apiUrl}/users/${userId}/password`, { password });
  }

  searchUsers(q: string): Observable<{ count: number; users: UserSearchResult[] }> {
    const params = new HttpParams().set('q', q);
    return this.http.get<{ count: number; users: UserSearchResult[] }>(
      `${environment.apiUrl}/auth/users/search`,
      { params }
    );
  }

  getLatestUsers(limit = 5): Observable<{ count: number; users: UserSearchResult[] }> {
    const params = new HttpParams().set('limit', limit.toString());
    return this.http.get<{ count: number; users: UserSearchResult[] }>(
      `${environment.apiUrl}/auth/users/latest`,
      { params }
    );
  }

  logout(): void {
    this.tokenStorage.clearToken();
    this.currentUser.set(null);
    this.isAuthenticated.set(false);
    this.router.navigate(['/login']);
  }

  getToken(): string | null {
    return this.tokenStorage.getToken();
  }

  private loadUserFromToken(): void {
    const token = this.getToken();
    if (!token) {
      this.authInitialized$.next(true);
      return;
    }

    // First paint must not wait on /auth/me (cold-start backend can be slow).
    const userFromToken = this.decodeUserFromToken(token);
    if (!userFromToken) {
      this.tokenStorage.clearToken();
      this.currentUser.set(null);
      this.isAuthenticated.set(false);
      this.authInitialized$.next(true);
      return;
    }

    this.currentUser.set(userFromToken);
    this.isAuthenticated.set(true);
    this.authInitialized$.next(true);

    // Keep server as source of truth, but validate in background with timeout.
    this.httpClient
      .get<{ user: User }>(`${this.apiUrl}/me`)
      .pipe(timeout(4000))
      .subscribe({
        next: (response) => {
          this.currentUser.set(response.user);
          this.isAuthenticated.set(true);
        },
        error: (err) => {
          // Only invalidate session when the backend explicitly rejects the token.
          if (err.status === 401 || err.status === 403) {
            this.tokenStorage.clearToken();
            this.currentUser.set(null);
            this.isAuthenticated.set(false);
            this.router.navigate(['/login']);
          }
        }
      });
  }

  private decodeUserFromToken(token: string): User | null {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const isExpired = payload.exp && payload.exp * 1000 < Date.now();

      if (isExpired) {
        return null;
      }

      if (!payload.role || (!payload.userId && !payload.id) || !payload.username || !payload.email) {
        return null;
      }

      return {
        id: payload.userId ?? payload.id,
        username: payload.username,
        displayName: payload.displayName,
        email: payload.email,
        role: payload.role
      };
    } catch {
      return null;
    }
  }
}
