# Settings Screen and Swagger API Documentation Implementation

This document describes the implementation of the Settings screen with display name functionality and Swagger API documentation.

## Overview

This implementation adds two major features to the How I Ate application:

1. **Settings Screen**: A user interface where authenticated users can view and update their display name
2. **Swagger API Documentation**: Interactive API documentation available at `http://localhost:3000/api`

## Backend Changes

### 1. Dependencies Added

```json
{
  "swagger-ui-express": "^5.0.1",
  "swagger-jsdoc": "^6.2.8"
}
```

### 2. User Model Updates

Added an optional `displayName` field to the User schema:

```javascript
displayName: {
  type: String,
  trim: true,
  maxlength: [50, 'Display name must not exceed 50 characters']
}
```

### 3. New API Endpoint

**PUT `/api/auth/profile`** - Update user profile (authenticated users only)

Request body:
```json
{
  "displayName": "John Doe"
}
```

Response:
```json
{
  "message": "Profile updated successfully",
  "user": {
    "id": "...",
    "username": "johndoe",
    "displayName": "John Doe",
    "email": "john@example.com",
    "role": "user"
  }
}
```

### 4. Updated Endpoints

All authentication endpoints now return `displayName` in the user object:
- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `POST /api/auth/create-admin`

### 5. Swagger API Documentation

Created comprehensive Swagger/OpenAPI 3.0 documentation for all API endpoints:

- **Location**: `http://localhost:3000/api`
- **Tags**: Authentication, Restaurants, Reviews
- **Security**: Bearer token authentication (JWT)
- **Schemas**: User, Restaurant, Review, Error

All endpoints are documented with:
- Request/response schemas
- Parameter descriptions
- Status codes
- Authentication requirements

## Frontend Changes

### 1. AuthService Updates

**Updated User Interface:**
```typescript
export interface User {
  id: string;
  username: string;
  displayName?: string;  // New field
  email: string;
  role: string;
}
```

**New Method:**
```typescript
updateProfile(displayName: string): Observable<any>
```

### 2. Settings Component

Created a new standalone Angular component at:
- `src/app/components/settings/settings.component.ts`
- `src/app/components/settings/settings.component.html`
- `src/app/components/settings/settings.component.css`

**Features:**
- View read-only account information (username, email, role)
- Update display name with real-time validation
- Success/error message feedback
- Consistent navigation with other pages
- Form validation (max 50 characters)
- Auto-dismissing success messages

### 3. Routing Updates

Added new route in `app.routes.ts`:
```typescript
{ path: 'settings', component: SettingsComponent }
```

### 4. Navigation Updates

Updated the Restaurants component navigation to:
- Include a "Settings" link in the navigation bar
- Display the user's display name (or username if not set) in the welcome message

Format: `Welcome, {displayName || username}`

## User Experience

### Settings Page Features

1. **Profile Information Section**:
   - Shows read-only fields: Username, Email, Role
   - Clear indication that these fields cannot be changed

2. **Display Name Management**:
   - Editable text input for display name
   - Maximum 50 characters
   - Optional field (can be left empty to use username)
   - Clear helper text explaining the purpose

3. **Feedback**:
   - Green success message on successful update
   - Red error message on failure
   - Messages auto-dismiss after 3-5 seconds
   - Loading state during API calls

4. **Navigation**:
   - Consistent header with "Restaurants" and "Settings" links
   - Active state indication
   - User greeting with display name
   - Logout button

## API Usage Examples

### Update Display Name

```bash
curl -X PUT http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"displayName": "John Doe"}'
```

### Clear Display Name

```bash
curl -X PUT http://localhost:3000/api/auth/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"displayName": ""}'
```

## Testing

### Backend Testing

1. Start the backend server:
   ```bash
   cd backend
   npm start
   ```

2. Access Swagger UI at `http://localhost:3000/api`

3. Test the profile update endpoint using Swagger's "Try it out" feature

### Frontend Testing

1. Start the frontend development server:
   ```bash
   cd frontend
   npm start
   ```

2. Login to the application

3. Navigate to Settings via the navigation bar

4. Update your display name and verify:
   - Success message appears
   - Display name updates in the navigation
   - Changes persist after page refresh

## Security Considerations

1. **Authentication Required**: All profile endpoints require valid JWT authentication
2. **Input Validation**: Display name is validated on both client and server
3. **Rate Limiting**: Profile update endpoint has write rate limiting (30 requests/15 minutes)
4. **XSS Prevention**: All user inputs are properly sanitized
5. **No Sensitive Data Exposure**: Only necessary user information is returned

## Browser Compatibility

The implementation uses modern Angular features and requires:
- Modern browsers with ES6+ support
- Chrome 90+, Firefox 88+, Safari 14+, Edge 90+

## File Structure

```
backend/
├── config/
│   └── swagger.js              # Swagger configuration
├── models/
│   └── User.js                 # Updated with displayName field
└── routes/
    └── auth.js                 # New profile update endpoint

frontend/
├── src/app/
│   ├── components/
│   │   ├── settings/           # New Settings component
│   │   └── restaurants/        # Updated navigation
│   ├── services/
│   │   └── auth.service.ts     # Updated with displayName support
│   └── app.routes.ts           # New settings route
```

## Future Enhancements

Potential improvements for future iterations:
1. Password change functionality
2. Email change with verification
3. Profile picture upload
4. Account deletion
5. Privacy settings
6. Notification preferences
7. Two-factor authentication

## Conclusion

This implementation successfully adds a Settings screen where users can manage their display name, along with comprehensive Swagger API documentation. The changes are minimal, focused, and maintain consistency with the existing application design and architecture.
