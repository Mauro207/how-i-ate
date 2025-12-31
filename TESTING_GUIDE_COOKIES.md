# Testing Guide: JWT Cookie Authentication

## Prerequisites

- Backend deployed and running
- Frontend deployed and running
- Environment variables configured correctly

## Local Testing

### 1. Backend Setup

```bash
cd backend
npm install
# Create .env file with required variables
npm start
```

Expected output:
```
Server is running on port 3000
MongoDB connected successfully
```

### 2. Frontend Setup

```bash
cd frontend
npm install
npm start
```

Expected output:
```
Angular Live Development Server is listening on localhost:4200
```

### 3. Test Login Flow

1. Navigate to `http://localhost:4200/login`
2. Enter valid credentials and login
3. Open browser DevTools > Application > Cookies
4. Verify `jwt` cookie is present with:
   - Name: `jwt`
   - Value: (JWT token string)
   - HttpOnly: ✓
   - Secure: (empty in dev, ✓ in prod)
   - SameSite: `Lax` (dev) or `None` (prod)

**Expected Result**: Cookie is set after successful login

### 4. Test Session Persistence

1. After logging in, refresh the page (F5)
2. Verify you remain logged in
3. Check DevTools Console for `/api/auth/me` call
4. Verify the call succeeds with user data

**Expected Result**: User remains logged in after refresh

### 5. Test Logout

1. Click logout button
2. Check browser cookies - `jwt` cookie should be deleted
3. Verify redirect to login page
4. Try accessing protected route - should redirect to login

**Expected Result**: Cookie cleared, user logged out

### 6. Test Cookie Expiration

Use browser DevTools to view cookie expiration:
```
Max-Age: 7776000 (90 days in seconds)
Expires: (date 90 days from now)
```

**Expected Result**: Cookie expires in 90 days

## Production Testing (Vercel)

### 1. Environment Verification

Backend environment variables:
```bash
# Check in Vercel dashboard
NODE_ENV=production
FRONTEND_URL=https://your-frontend.vercel.app
JWT_SECRET=your-secure-secret
MONGODB_URI=your-mongodb-uri
```

### 2. HTTPS Verification

1. Open `https://your-frontend.vercel.app`
2. Click lock icon in address bar
3. Verify SSL certificate is valid
4. Check "Connection is secure"

**Expected Result**: Valid HTTPS connection

### 3. Cookie Security Attributes

After login, check cookie in DevTools:
```
Name: jwt
HttpOnly: ✓
Secure: ✓
SameSite: None
Domain: your-backend.vercel.app
Path: /
```

**Expected Result**: All security attributes set correctly

### 4. Cross-Domain Cookie Test

1. Login from `https://your-frontend.vercel.app`
2. Verify cookie is sent to `https://your-backend.vercel.app`
3. Check Network tab - cookies sent with requests
4. Verify `withCredentials: true` in request headers

**Expected Result**: Cookies work across domains

### 5. CORS Verification

Open browser console and check for CORS errors:
```
✓ No "Access-Control-Allow-Origin" errors
✓ No "Access-Control-Allow-Credentials" errors
```

**Expected Result**: No CORS errors

## API Testing with cURL

### Test Login and Cookie Setting

```bash
curl -v -X POST \
  https://your-backend.vercel.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' \
  -c cookies.txt
```

Check response headers for `Set-Cookie`:
```
Set-Cookie: jwt=<token>; HttpOnly; Secure; SameSite=None; Max-Age=7776000
```

### Test Authenticated Request with Cookie

```bash
curl -v -X GET \
  https://your-backend.vercel.app/api/auth/me \
  -b cookies.txt
```

**Expected Result**: User profile returned

### Test Logout

```bash
curl -v -X POST \
  https://your-backend.vercel.app/api/auth/logout \
  -b cookies.txt \
  -c cookies.txt
```

Check response headers for cookie deletion:
```
Set-Cookie: jwt=; HttpOnly; Secure; SameSite=None; Max-Age=0
```

## Automated Testing Checklist

- [ ] Backend starts without errors
- [ ] Frontend compiles and serves
- [ ] Login sets JWT cookie
- [ ] Cookie has correct security attributes (HttpOnly, Secure, SameSite)
- [ ] Authenticated requests include cookie
- [ ] Page refresh preserves session
- [ ] Logout clears cookie
- [ ] Invalid token returns 401
- [ ] Expired token returns 401
- [ ] No CORS errors in console
- [ ] HTTPS enforced in production

## Common Issues and Solutions

### Issue: Cookie not being set in production

**Check**:
- Backend `NODE_ENV=production`
- `FRONTEND_URL` matches actual domain
- Both domains use HTTPS
- Browser doesn't block third-party cookies

### Issue: Session lost after refresh

**Check**:
- Cookie present in DevTools
- `/api/auth/me` endpoint called
- Cookie domain matches backend
- Cookie not expired

### Issue: CORS errors

**Check**:
- `FRONTEND_URL` environment variable
- Backend CORS configuration
- `withCredentials: true` in frontend
- Both domains use HTTPS

### Issue: Cookie not sent with requests

**Check**:
- `withCredentials: true` in HTTP client
- Cookie domain and path match request
- Cookie hasn't expired
- Browser cookie settings allow cookies

## Performance Testing

Test the following scenarios:

1. **Load Test**: 100 concurrent login requests
2. **Session Test**: 1000 concurrent authenticated requests
3. **Refresh Test**: Rapid page refreshes (10 per second)

**Expected Results**:
- All requests succeed
- No token validation errors
- Response times under 200ms
- No memory leaks

## Security Testing

### Test XSS Protection

Try to access cookie via JavaScript console:
```javascript
document.cookie
```

**Expected Result**: JWT cookie not visible (HttpOnly protection)

### Test CSRF Protection

Try cross-site request without proper origin:
```bash
curl -X POST https://your-backend.vercel.app/api/restaurants \
  -H "Origin: https://malicious-site.com" \
  -H "Cookie: jwt=<token>"
```

**Expected Result**: Request blocked by CORS

### Test Token Validation

1. Modify cookie value in DevTools
2. Make authenticated request
3. Verify 401 Unauthorized response

**Expected Result**: Invalid token rejected

## Conclusion

After completing all tests:

✅ **Pass**: Cookie authentication working correctly  
❌ **Fail**: Issues found, review implementation

For any failures, refer to:
- COOKIE_AUTH_IMPLEMENTATION.md
- SECURITY_SUMMARY_COOKIES.md
- Backend logs in Vercel dashboard
