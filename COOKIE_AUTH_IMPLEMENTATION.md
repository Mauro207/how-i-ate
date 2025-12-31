# JWT Cookie Authentication Implementation

## Overview

This implementation adds JWT cookie-based authentication to persist user sessions across browser refreshes. The solution is compatible with Vercel's free tier.

## Changes Made

### Backend Changes

1. **Added cookie-parser dependency**
   - Installed `cookie-parser` package to handle HTTP cookies

2. **Updated `backend/index.js`**
   - Added `cookie-parser` middleware
   - Updated CORS configuration to enable credentials
   - Added support for multiple frontend origins (comma-separated)

3. **Updated `backend/middleware/auth.js`**
   - Modified authentication middleware to read JWT from cookies first
   - Falls back to Authorization header for backward compatibility
   - Supports both cookie-based and Bearer token authentication

4. **Updated `backend/routes/auth.js`**
   - Modified `/login` endpoint to set HTTP-only cookie with JWT
   - Modified `/register` endpoint to set HTTP-only cookie with JWT
   - Added `/logout` endpoint to clear authentication cookie
   - Cookie settings:
     - `httpOnly: true` - Prevents JavaScript access (XSS protection)
     - `secure: true` in production - HTTPS only
     - `sameSite: 'none'` in production - Cross-site cookie support for Vercel
     - `sameSite: 'lax'` in development - Local development support
     - `maxAge: 90 days` - Long-lived session

### Frontend Changes

1. **Updated `frontend/src/app/app.config.ts`**
   - Added `withFetch()` to HTTP client configuration

2. **Updated `frontend/src/app/interceptors/auth.interceptor.ts`**
   - Added `withCredentials: true` to all HTTP requests
   - Maintains backward compatibility with Authorization header

3. **Updated `frontend/src/app/services/auth.service.ts`**
   - Modified `logout()` method to call backend `/logout` endpoint
   - Ensures cookie is properly cleared on server side

## Vercel Deployment

### Backend Environment Variables

Set these environment variables in your Vercel backend project:

```
NODE_ENV=production
FRONTEND_URL=https://your-frontend-domain.vercel.app
JWT_SECRET=your-secure-random-secret
JWT_EXPIRES_IN=90d
MONGODB_URI=your-mongodb-connection-string
SUPERADMIN_PASSWORD=your-secure-password
```

**Important**: 
- `FRONTEND_URL` must match your actual frontend domain
- `JWT_SECRET` should be a strong, random string
- For multiple origins, separate them with commas: `https://domain1.vercel.app,https://domain2.vercel.app`

### Frontend Environment Variables

Update `frontend/src/environments/environment.prod.ts`:

```typescript
export const environment = {
  production: true,
  apiUrl: 'https://your-backend-domain.vercel.app/api'
};
```

## How It Works

1. **Login/Register Flow**:
   - User submits credentials
   - Backend validates and generates JWT
   - Backend sets HTTP-only cookie with JWT
   - Backend also returns JWT in response body (for localStorage fallback)
   - Frontend stores user data

2. **Authenticated Requests**:
   - Frontend sends requests with `withCredentials: true`
   - Browser automatically includes cookies
   - Backend checks cookie for JWT first
   - Falls back to Authorization header if no cookie found

3. **Page Refresh**:
   - Cookie persists in browser
   - Frontend calls `/api/auth/me` on app initialization
   - Backend validates JWT from cookie
   - User session is restored without re-login

4. **Logout Flow**:
   - Frontend calls `/api/auth/logout`
   - Backend clears the cookie
   - Frontend clears localStorage and redirects to login

## Security Features

- **HTTP-only cookies**: JavaScript cannot access the token, preventing XSS attacks
- **Secure flag**: Cookies only sent over HTTPS in production
- **SameSite attribute**: Protection against CSRF attacks
  - `lax` in development: Prevents cookies from being sent in most cross-site requests
  - `none` in production: Required for cross-domain cookies with Vercel, combined with `secure` flag
  - No additional CSRF token needed as API uses stateless JWT authentication
- **CORS with credentials**: Restricted to specific frontend origins
- **Dual authentication**: Supports both cookie and Bearer token methods

## Testing

### Local Testing

1. Start backend:
   ```bash
   cd backend
   npm start
   ```

2. Start frontend:
   ```bash
   cd frontend
   npm start
   ```

3. Test flow:
   - Login to the application
   - Check browser DevTools > Application > Cookies for `jwt` cookie
   - Refresh the page - should remain logged in
   - Logout - cookie should be cleared

### Vercel Testing

1. Deploy backend and frontend to Vercel
2. Configure environment variables as described above
3. Test the same flow in production
4. Verify cookies are set with `Secure` and `SameSite=None` attributes

## Troubleshooting

### Issue: Cookies not being set

**Solution**: 
- Verify `FRONTEND_URL` matches the actual frontend domain
- Check browser console for CORS errors
- Ensure backend is deployed with HTTPS (required for secure cookies)

### Issue: Session lost on refresh

**Solution**:
- Check if cookie exists in browser DevTools
- Verify `/api/auth/me` endpoint is being called
- Check if cookie domain matches backend domain

### Issue: CORS errors in production

**Solution**:
- Ensure `FRONTEND_URL` environment variable is set correctly
- Verify `sameSite: 'none'` for cross-site cookies
- Confirm both frontend and backend use HTTPS

### CSRF Protection

**Q: Do we need additional CSRF protection?**

**A**: No. The implementation provides adequate CSRF protection through:
- `sameSite` cookie attribute prevents cross-site request forgery
- CORS configuration restricts allowed origins
- JWT tokens in cookies are stateless (no server-side session state)
- All state-changing operations require valid JWT authentication

Traditional CSRF tokens are not needed for REST APIs using JWT authentication without session state.

## Backward Compatibility

The implementation maintains backward compatibility:
- Authorization header authentication still works
- localStorage token is still set (optional fallback)
- Existing API clients using Bearer tokens continue to work

## Future Improvements

Possible enhancements:
- Refresh token rotation
- Device-specific session management
- Session expiry notifications
- Token revocation system
