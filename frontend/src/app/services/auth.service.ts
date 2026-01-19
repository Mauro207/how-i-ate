import { Injectable, signal, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Router } from '@angular/router';
import { Observable, tap } from 'rxjs';
import { environment } from '../../environments/environment';

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
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = `${environment.apiUrl}/auth`;
  private tokenKey = 'auth_token';
  private http = inject(HttpClient);

  currentUser = signal<User | null>(null);
  isAuthenticated = signal<boolean>(false);

  constructor(private httpClient: HttpClient, private router: Router) {
    this.loadUserFromToken();
  }

  login(email: string, password: string): Observable<LoginResponse> {
    return this.httpClient.post<LoginResponse>(`${this.apiUrl}/login`, { email, password })
      .pipe(
        tap(response => {
          localStorage.setItem(this.tokenKey, response.token);
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

  logout(): void {
    localStorage.removeItem(this.tokenKey);
    this.currentUser.set(null);
    this.isAuthenticated.set(false);
    this.router.navigate(['/login']);
  }

  getToken(): string | null {
    return localStorage.getItem(this.tokenKey);
  }

  private loadUserFromToken(): void {
    const token = this.getToken();
    if (token) {
      this.httpClient.get<{ user: User }>(`${this.apiUrl}/me`).subscribe({
        next: (response) => {
          this.currentUser.set(response.user);
          this.isAuthenticated.set(true);
        },
        error: () => {
          localStorage.removeItem(this.tokenKey);
          this.isAuthenticated.set(false);
        }
      });
    }
  }
}
