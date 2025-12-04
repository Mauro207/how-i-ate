# Backend - How I Ate API

Node.js/Express backend server for the How I Ate application.

## Features

- Express.js server
- CORS enabled for frontend communication
- Environment variable support with dotenv
- RESTful API structure

## Prerequisites

- Node.js v20 or higher
- npm v10 or higher

## Installation

```bash
npm install
```

## Configuration

Create a `.env` file based on `.env.example`:

```bash
cp .env.example .env
```

Configure the following environment variables:

- `PORT` - Server port (default: 3000)
- `NODE_ENV` - Environment (development/production)

## Running the Server

### Development
```bash
npm run dev
```

### Production
```bash
npm start
```

The server will be available at `http://localhost:3000`

## API Endpoints

### Health Check
```
GET /api/health
```

Returns the server health status.

**Response:**
```json
{
  "status": "OK",
  "timestamp": "2025-12-04T10:00:00.000Z"
}
```

### Welcome
```
GET /
```

Returns a welcome message.

**Response:**
```json
{
  "message": "Welcome to How I Ate API"
}
```

## Project Structure

```
backend/
├── index.js           # Main server file
├── package.json       # Dependencies and scripts
├── .env.example       # Environment variables template
└── .env              # Local environment variables (not committed)
```

## Dependencies

- **express** - Fast, minimalist web framework
- **cors** - Enable CORS with various options
- **dotenv** - Load environment variables from .env file
