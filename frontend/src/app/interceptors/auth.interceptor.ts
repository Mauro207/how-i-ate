import { HttpInterceptorFn } from '@angular/common/http';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const isPublicAuthRequest =
    req.url.includes('/auth/login') ||
    req.url.includes('/auth/register');

  if (isPublicAuthRequest) {
    return next(req);
  }

  const token = localStorage.getItem('auth_token');
  
  if (token) {
    const cloned = req.clone({
      headers: req.headers.set('Authorization', `Bearer ${token}`)
    });
    return next(cloned);
  }
  
  return next(req);
};
