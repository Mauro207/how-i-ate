# how-i-ate

A full-stack application with Angular frontend and Node.js backend for restaurant reviews.

## Features

- **User Authentication**: JWT-based authentication system
- **Role-Based Access Control**: Three user roles (superadmin, admin, user)
- **Restaurant Management**: Admins can create and manage restaurant entries
- **Review System**: All authenticated users can leave reviews for restaurants

## Project Structure

```
how-i-ate/
├── frontend/          # Angular application
│   ├── src/          # Angular source code
│   ├── package.json  # Frontend dependencies
│   └── angular.json  # Angular configuration
│
└── backend/          # Node.js/Express backend
    ├── index.js      # Main server file
    ├── models/       # Mongoose models
    ├── routes/       # API routes
    ├── middleware/   # Custom middleware
    ├── config/       # Configuration files
    ├── package.json  # Backend dependencies
    └── .env.example  # Environment variables template
```

## Prerequisites

- Node.js (v20 or higher)
- npm (v10 or higher)
- MongoDB Atlas account (or local MongoDB instance)

## Getting Started

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Create a `.env` file from the example:
   ```bash
   cp .env.example .env
   ```

4. Update the `.env` file with your configuration:
   - `MONGODB_URI`: Your MongoDB connection string (provided: `mongodb+srv://how-i-ate_db_user:5qAlW2jWNficu6E0@how-i-ate.ew2p1cl.mongodb.net/?appName=how-i-ate`)
   - `JWT_SECRET`: A secure random string for JWT signing
   - `JWT_EXPIRES_IN`: Token expiration time (default: 7d)
   - `SUPERADMIN_PASSWORD`: (Optional) Custom password for superadmin account. If not set, defaults to `SuperAdmin123!`

5. Initialize the superadmin account:
   ```bash
   npm run init-superadmin
   ```
   
   Default credentials:
   - Username: `superadmin`
   - Email: `superadmin@howiate.com`
   - Password: `SuperAdmin123!`
   
   **IMPORTANT**: Change the password after first login!

6. Start the server:
   ```bash
   npm start
   ```

   The backend server will run on `http://localhost:3000`

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm start
   ```

   The Angular application will run on `http://localhost:4200`

### Build for Production

#### Backend
```bash
cd backend
npm start
```

#### Frontend
```bash
cd frontend
npm run build
```

The production build will be available in `frontend/dist/`

## User Roles

### Superadmin
- Can create admin users
- Can create, update, and delete restaurants
- Can create, update, and delete any review

### Admin
- Can create, update, and delete restaurants
- Can create, update, and delete any review

### User
- Can create and update their own reviews
- Can view all restaurants and reviews

## API Endpoints

### Authentication

#### Register User
```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "password123"
}
```

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "john@example.com",
  "password": "password123"
}
```

Response:
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "...",
    "username": "john_doe",
    "email": "john@example.com",
    "role": "user"
  }
}
```

#### Get Current User
```http
GET /api/auth/me
Authorization: Bearer <token>
```

#### Create Admin User (Superadmin only)
```http
POST /api/auth/create-admin
Authorization: Bearer <token>
Content-Type: application/json

{
  "username": "admin_user",
  "email": "admin@example.com",
  "password": "password123"
}
```

### Restaurants

#### Get All Restaurants
```http
GET /api/restaurants
Authorization: Bearer <token>
```

#### Get Single Restaurant
```http
GET /api/restaurants/:id
Authorization: Bearer <token>
```

#### Create Restaurant (Admin/Superadmin only)
```http
POST /api/restaurants
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "The Great Restaurant",
  "description": "Amazing food and service",
  "address": "123 Main St, City",
  "cuisine": "Italian"
}
```

#### Update Restaurant (Admin/Superadmin only)
```http
PUT /api/restaurants/:id
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Updated Restaurant Name",
  "description": "Updated description"
}
```

#### Delete Restaurant (Admin/Superadmin only)
```http
DELETE /api/restaurants/:id
Authorization: Bearer <token>
```

### Reviews

#### Get All Reviews for a Restaurant
```http
GET /api/reviews/restaurant/:restaurantId
Authorization: Bearer <token>
```

#### Get Single Review
```http
GET /api/reviews/:id
Authorization: Bearer <token>
```

#### Create Review
```http
POST /api/reviews/restaurant/:restaurantId
Authorization: Bearer <token>
Content-Type: application/json

{
  "rating": 5,
  "comment": "Excellent food and service!"
}
```

#### Update Review (Owner only)
```http
PUT /api/reviews/:id
Authorization: Bearer <token>
Content-Type: application/json

{
  "rating": 4,
  "comment": "Updated review comment"
}
```

#### Delete Review (Owner/Admin/Superadmin)
```http
DELETE /api/reviews/:id
Authorization: Bearer <token>
```

### Other Endpoints

- `GET /` - Welcome message
- `GET /api/health` - Health check endpoint

## Development

- Backend runs on port 3000 (configurable via .env)
- Frontend runs on port 4200 (Angular default)
- CORS is enabled for local development
- JWT tokens expire after 7 days (configurable)

## Database Models

### User
- username (unique, required)
- email (unique, required)
- password (hashed, required)
- role (user/admin/superadmin)
- createdBy (reference to User who created this user)

### Restaurant
- name (required)
- description
- address
- cuisine
- createdBy (reference to User)

### Review
- restaurant (reference to Restaurant)
- user (reference to User)
- rating (1-5, required)
- comment (required)
- Unique constraint: one review per user per restaurant

## Security Notes

1. Passwords are hashed using bcrypt
2. JWT tokens are used for authentication
3. Role-based authorization is enforced on protected routes
4. The `.env` file containing sensitive data is excluded from version control
5. Change the default superadmin password immediately after setup
