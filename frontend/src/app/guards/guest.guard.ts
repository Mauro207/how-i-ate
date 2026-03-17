import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { filter, switchMap, take } from 'rxjs/operators';
import { of } from 'rxjs';

export const guestGuard: CanActivateFn = () => {
  const authService = inject(AuthService);
  const router = inject(Router);

  return authService.authInitialized.pipe(
    filter(initialized => initialized),
    take(1),
    switchMap(() => {
      if (!authService.isAuthenticated()) {
        return of(true);
      }

      router.navigate(['/restaurants']);
      return of(false);
    })
  );
};