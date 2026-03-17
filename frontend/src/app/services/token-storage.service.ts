import { Injectable } from '@angular/core';

@Injectable({
  providedIn: 'root'
})
export class TokenStorageService {
  private readonly tokenKey = 'auth_token';
  private readonly fallbackCookieKey = 'auth_token_fallback';
  private readonly cookieMaxAgeSeconds = 60 * 60 * 24 * 365;

  getToken(): string | null {
    const localToken = this.readLocalStorage();

    if (localToken) {
      this.writeCookie(localToken);
      return localToken;
    }

    const cookieToken = this.readCookie();
    if (!cookieToken) {
      return null;
    }

    this.writeLocalStorage(cookieToken);
    return cookieToken;
  }

  setToken(token: string): void {
    this.writeLocalStorage(token);
    this.writeCookie(token);
  }

  clearToken(): void {
    this.removeLocalStorage();
    this.removeCookie();
  }

  private readLocalStorage(): string | null {
    try {
      return typeof localStorage === 'undefined' ? null : localStorage.getItem(this.tokenKey);
    } catch {
      return null;
    }
  }

  private writeLocalStorage(token: string): void {
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem(this.tokenKey, token);
      }
    } catch {
      // Ignore storage failures and rely on the cookie fallback.
    }
  }

  private removeLocalStorage(): void {
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.removeItem(this.tokenKey);
      }
    } catch {
      // Ignore storage cleanup failures.
    }
  }

  private readCookie(): string | null {
    if (typeof document === 'undefined') {
      return null;
    }

    const cookiePrefix = `${this.fallbackCookieKey}=`;
    const cookies = document.cookie ? document.cookie.split('; ') : [];
    const match = cookies.find(cookie => cookie.startsWith(cookiePrefix));

    if (!match) {
      return null;
    }

    const value = match.slice(cookiePrefix.length);
    return value ? decodeURIComponent(value) : null;
  }

  private writeCookie(token: string): void {
    if (typeof document === 'undefined') {
      return;
    }

    const secure = typeof location !== 'undefined' && location.protocol === 'https:' ? '; Secure' : '';
    document.cookie = `${this.fallbackCookieKey}=${encodeURIComponent(token)}; Path=/; Max-Age=${this.cookieMaxAgeSeconds}; SameSite=Strict${secure}`;
  }

  private removeCookie(): void {
    if (typeof document === 'undefined') {
      return;
    }

    const secure = typeof location !== 'undefined' && location.protocol === 'https:' ? '; Secure' : '';
    document.cookie = `${this.fallbackCookieKey}=; Path=/; Max-Age=0; SameSite=Strict${secure}`;
  }
}