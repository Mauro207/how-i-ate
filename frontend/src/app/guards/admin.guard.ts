import { inject } from '@angular/core';
import { Router, CanActivateFn } from '@angular/router';
import { AuthService } from '../services/auth.service';
import { filter, switchMap, take } from 'rxjs/operators';
import { of } from 'rxjs';

export const adminGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  return authService.authInitialized.pipe(
    filter(initialized => initialized),
    take(1),
    switchMap(() => {
      const user = authService.currentUser();

      if (authService.isAuthenticated() && (user?.role === 'admin' || user?.role === 'superadmin')) {
        return of(true);
      }

      if (!authService.isAuthenticated()) {
        router.navigate(['/login'], { queryParams: { returnUrl: state.url } });
      } else {
        router.navigate(['/restaurants']);
      }

      return of(false);
    })
  );
};
