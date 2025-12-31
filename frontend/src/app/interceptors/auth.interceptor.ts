import { HttpInterceptorFn } from '@angular/common/http';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('auth_token');
  
  // Clone request with credentials
  let cloned = req.clone({
    withCredentials: true
  });
  
  // Add Authorization header if token exists (for backward compatibility)
  if (token) {
    cloned = cloned.clone({
      headers: req.headers.set('Authorization', `Bearer ${token}`)
    });
  }
  
  return next(cloned);
};
