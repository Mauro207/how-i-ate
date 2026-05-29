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
- `MONGODB_URI` or `DATABASE_URL` - MongoDB connection string
- `VAPID_PUBLIC_KEY` and `VAPID_PRIVATE_KEY` - Web Push keys used by Chrome, Safari and other Push API browsers
- `VAPID_SUBJECT` - Contact subject for VAPID, for example `mailto:admin@example.com`
- `APNS_TEAM_ID` - Apple Developer Team ID for APNs token auth
- `APNS_KEY_ID` - Key ID of the APNs `.p8` key
- `APNS_PRIVATE_KEY` - Contents of APNs `.p8` key (supports `\\n` escaped new lines)
- `APNS_BUNDLE_ID` - iOS app bundle identifier used as APNs topic (for example `com.howiate.app`)
- `APNS_PRODUCTION` - `true` for production APNs, `false` for sandbox (default)
- `CRON_SECRET` - Optional shared secret for scheduled notification endpoints

## Scheduled Notifications

The weekly review reminder is exposed at:

```http
GET /api/notifications/weekly-review-reminder
```

`backend/vercel.json` schedules it at `20:30` and `21:30` UTC every Sunday. The endpoint only sends when the current time in `Europe/Rome` is Sunday between `22:20` and `22:45`, so the same configuration works across daylight saving time changes and remains idempotent through `NotificationRun`.

If `CRON_SECRET` is set, call the endpoint with one of:

- `Authorization: Bearer <CRON_SECRET>`
- `x-cron-secret: <CRON_SECRET>`
- `?secret=<CRON_SECRET>`

## Native iOS Push (APNs)

The backend supports native iOS push registration for authenticated users:

```http
POST /api/notifications/native/subscribe
DELETE /api/notifications/native/unsubscribe
```

Subscribe request body:

```json
{
  "deviceToken": "<apns-device-token-hex>",
  "provider": "apns",
  "client": {
    "platform": "ios",
    "appVersion": "1.0",
    "buildNumber": "1",
    "bundleId": "com.howiate.app"
  }
}
```

Notification senders now fan out to both web push (VAPID) and native APNs when configured.

Provider diagnostic endpoint:

```http
GET /api/notifications/providers
```

Example response:

```json
{
  "webPush": {
    "configured": true
  },
  "apns": {
    "configured": true,
    "production": false,
    "hasBundleId": true
  }
}
```

### APNs deployment checklist (Vercel)

1. Open Vercel project settings: **Settings > Environment Variables**.
2. Add these variables in `Development`, `Preview`, and `Production` as needed:
   - `APNS_TEAM_ID`
   - `APNS_KEY_ID`
   - `APNS_PRIVATE_KEY`
   - `APNS_BUNDLE_ID`
   - `APNS_PRODUCTION` (`false` for sandbox/debug builds, `true` for TestFlight/App Store)
3. Paste `APNS_PRIVATE_KEY` as full `.p8` content (real new lines or escaped `\\n` are both supported).
4. Redeploy the project after saving env vars.
5. Verify provider status:
   - `GET /api/notifications/providers` must return `apns.configured: true`.
6. Validate end-to-end with an authenticated user:
   - `POST /api/notifications/native/subscribe`
   - `POST /api/notifications/test`

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
