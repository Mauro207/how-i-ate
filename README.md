# how-i-ate

A full-stack application with Angular frontend and Node.js backend.

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
    ├── package.json  # Backend dependencies
    └── .env.example  # Environment variables template
```

## Prerequisites

- Node.js (v20 or higher)
- npm (v10 or higher)

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

4. Start the server:
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

## API Endpoints

- `GET /` - Welcome message
- `GET /api/health` - Health check endpoint

## Development

- Backend runs on port 3000 (configurable via .env)
- Frontend runs on port 4200 (Angular default)
- CORS is enabled for local development
