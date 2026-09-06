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

export interface UserProfile {
  user: {
    id: string;
    username: string;
    displayName?: string;
    role: 'user' | 'admin' | 'superadmin';
    createdAt?: string;
  };
  stats: {
    reviewCount: number;
    suggestedPlaceCount: number | null;
  };
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = `${environment.apiUrl}/auth`;
  private readonly userCacheKey = 'auth_user_profile';
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
          this.storeCachedUser(response.user);
        })
      );
  }

  register(name: string, email: string, password: string, invitationToken: string): Observable<LoginResponse> {
    return this.httpClient.post<LoginResponse>(`${this.apiUrl}/register`, { name, email, password, invitationToken }).pipe(
      tap(response => {
        this.tokenStorage.setToken(response.token);
        this.currentUser.set(response.user);
        this.isAuthenticated.set(true);
        this.storeCachedUser(response.user);
      })
    );
  }

  getInvitation(): Observable<{ token: string; dismissed: boolean }> {
    return this.httpClient.post<{ token: string; dismissed: boolean }>(`${this.apiUrl}/invitation`, {});
  }

  getInvitationStatus(): Observable<{ dismissed: boolean }> {
    return this.httpClient.get<{ dismissed: boolean }>(`${this.apiUrl}/invitation/status`);
  }

  dismissInvitationPrompt(): Observable<{ dismissed: boolean }> {
    return this.httpClient.patch<{ dismissed: boolean }>(`${this.apiUrl}/invitation/dismiss`, {});
  }

  previewInvitation(token: string): Observable<{ inviter: { name: string } }> {
    return this.httpClient.get<{ inviter: { name: string } }>(`${this.apiUrl}/invitation/${encodeURIComponent(token)}`);
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
          this.storeCachedUser(response.user);
        })
      );
  }

  getAllUsers(): Observable<{ users: User[] }> {
    return this.httpClient.get<{ users: User[] }>(`${this.apiUrl}/users`);
  }

  updateUserPassword(userId: string, password: string): Observable<{ message: string }> {
    return this.httpClient.put<{ message: string }>(`${this.apiUrl}/users/${userId}/password`, { password });
  }

  deleteUser(userId: string): Observable<{ message: string; deletedUserId: string }> {
    return this.httpClient.delete<{ message: string; deletedUserId: string }>(`${this.apiUrl}/users/${userId}`);
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

  getUserProfile(userId: string): Observable<UserProfile> {
    return this.http.get<UserProfile>(`${environment.apiUrl}/auth/users/${userId}/profile`);
  }

  logout(): void {
    this.tokenStorage.clearToken();
    this.clearCachedUser();
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

    const payload = this.decodeTokenPayload(token);
    if (!payload?.id) {
      this.tokenStorage.clearToken();
      this.clearCachedUser();
      this.currentUser.set(null);
      this.isAuthenticated.set(false);
      this.authInitialized$.next(true);
      return;
    }

    // First paint must not wait on /auth/me (cold-start backend can be slow).
    const cachedUser = this.getCachedUser();
    if (cachedUser && cachedUser.id === payload.id) {
      this.currentUser.set(cachedUser);
    } else {
      // Backend JWT currently contains only userId. Keep session active and
      // hydrate full profile from /auth/me in background.
      this.currentUser.set({
        id: payload.id,
        username: 'Utente',
        email: '',
        role: 'user'
      });
    }

    this.isAuthenticated.set(true);
    this.authInitialized$.next(true);

    // Keep server as source of truth, but validate in background with timeout.
    this.httpClient
      .get<{ user: User }>(`${this.apiUrl}/me`)
      .pipe(timeout(5000))
      .subscribe({
        next: (response) => {
          this.currentUser.set(response.user);
          this.isAuthenticated.set(true);
          this.storeCachedUser(response.user);
        },
        error: (err) => {
          // Only invalidate session when the backend explicitly rejects the token.
          if (err.status === 401 || err.status === 403) {
            this.tokenStorage.clearToken();
            this.clearCachedUser();
            this.currentUser.set(null);
            this.isAuthenticated.set(false);
            this.router.navigate(['/login']);
          }
        }
      });
  }

  private decodeTokenPayload(token: string): { id: string } | null {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const isExpired = payload.exp && payload.exp * 1000 < Date.now();

      if (isExpired) {
        return null;
      }

      const id = payload.userId ?? payload.id;
      if (!id) {
        return null;
      }

      return { id };
    } catch {
      return null;
    }
  }

  private storeCachedUser(user: User): void {
    try {
      localStorage.setItem(this.userCacheKey, JSON.stringify(user));
    } catch {
      // Ignore cache failures.
    }
  }

  private getCachedUser(): User | null {
    try {
      const raw = localStorage.getItem(this.userCacheKey);
      if (!raw) {
        return null;
      }

      const parsed = JSON.parse(raw) as Partial<User>;
      if (!parsed.id || !parsed.username || !parsed.role) {
        return null;
      }

      return {
        id: parsed.id,
        username: parsed.username,
        displayName: parsed.displayName,
        email: parsed.email ?? '',
        role: parsed.role
      };
    } catch {
      return null;
    }
  }

  private clearCachedUser(): void {
    try {
      localStorage.removeItem(this.userCacheKey);
    } catch {
      // Ignore cache cleanup failures.
    }
  }
}
