# 🚀 Deployment Guide: Postgres Migration

## Overview
This app now uses **Postgres** instead of SQLite, with a sync engine that works locally first, then syncs to cloud.

## Local Development Setup

### 1. Install Postgres Locally

**macOS (using Homebrew):**
```bash
brew install postgresql@15
brew services start postgresql@15
```

**Create Database:**
```bash
createdb anti_doomscroll
```

### 2. Configure Environment Variables

Create/update `.env` file in `backend/`:
```env
# Postgres (Local)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=anti_doomscroll

# Keep existing keys
HUME_API_KEY=your_key
HUME_SECRET_KEY=your_secret
GEMINI_API_KEY=your_key
# ... etc
```

### 3. Install Dependencies
```bash
cd backend
pip install -r requirements.txt
```

### 4. Run Migration (if migrating from SQLite)
```bash
python migrate_to_postgres.py
```

### 5. Start Backend
```bash
# Make sure IS_LOCAL = True in db.py
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### 6. Update iOS App
In `APIConfig.swift`, uncomment the local URL:
```swift
static var baseURL: String {
    // Shared.defaults.set("https://ds-sqxf.onrender.com", forKey: Shared.baseURLKey)
    Shared.defaults.set("http://192.168.1.159:8000", forKey: Shared.baseURLKey)
    return Shared.defaults.string(forKey: Shared.baseURLKey) ?? "IMPOSSIBLE"
}
```

---

## Cloud Deployment (Render)

### 1. Set Environment Variables in Render Dashboard

Go to your Render service → Environment:
```env
# Postgres (from Render's Postgres service)
DATABASE_URL=postgresql://user:pass@host:5432/dbname

# Other keys
HUME_API_KEY=your_key
HUME_SECRET_KEY=your_secret
GEMINI_API_KEY=your_key
# ... etc
```

### 2. Update Backend Code

In `backend/db.py`, change:
```python
IS_LOCAL = False  # Set to False when deploying to cloud
```

### 3. Deploy

Push to your Git repo, Render will auto-deploy.

### 4. Update iOS App

In `APIConfig.swift`, use the cloud URL:
```swift
static var baseURL: String {
    Shared.defaults.set("https://ds-sqxf.onrender.com", forKey: Shared.baseURLKey)
    // Shared.defaults.set("http://192.168.1.159:8000", forKey: Shared.baseURLKey)
    return Shared.defaults.string(forKey: Shared.baseURLKey) ?? "IMPOSSIBLE"
}
```

---

## Database Schema

### `todos` table (kept as is)
- `id` (Integer, Primary Key)
- `task` (String)
- `phone` (String, Indexed)
- `synced_at` (DateTime, auto-updated)
- `created_at` (DateTime, auto-set)

### `profiles` table (new)
- `id` (Integer, Primary Key)
- `phone` (String, Unique, Indexed)
- `is_premium` (Boolean, default: False)
- `last_active` (DateTime, auto-updated)
- `created_at` (DateTime, auto-set)
- `updated_at` (DateTime, auto-updated)

---

## Testing

### Test Local Connection
```bash
psql -U postgres -d anti_doomscroll -c "SELECT COUNT(*) FROM todos;"
```

### Test API
```bash
curl -H "x-phone: 123" http://localhost:8000/todos
```

---

## Troubleshooting

**"Connection refused"**
- Check Postgres is running: `brew services list`
- Check port: `lsof -i :5432`

**"Database does not exist"**
- Create it: `createdb anti_doomscroll`

**"Authentication failed"**
- Check `.env` file has correct credentials
