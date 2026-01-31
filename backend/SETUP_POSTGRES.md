# 🐘 Quick Postgres Setup Guide

## Local Setup (macOS)

### 1. Install Postgres
```bash
brew install postgresql@15
brew services start postgresql@15
```

### 2. Create Database
```bash
createdb anti_doomscroll
```

### 3. Verify Installation
```bash
psql -d anti_doomscroll -c "SELECT version();"
```

### 4. Test Connection
```bash
psql -d anti_doomscroll
```

You should see: `anti_doomscroll=#`

Type `\q` to exit.

---

## Cloud Setup (Render)

### Option 1: Use Render's Managed Postgres

1. Go to Render Dashboard → New → PostgreSQL
2. Name it: `anti-doomscroll-db`
3. Copy the **Internal Database URL** (starts with `postgresql://`)
4. Add it to your backend service's environment variables as `DATABASE_URL`

### Option 2: Use Supabase

1. Go to [supabase.com](https://supabase.com)
2. Create a new project
3. Go to Settings → Database
4. Copy the **Connection string** (URI mode)
5. Add it to your backend service's environment variables as `DATABASE_URL`

---

## Migration from SQLite

If you have existing data in `todos.db`:

```bash
cd backend
python migrate_to_postgres.py
```

This will:
- Read all todos from SQLite
- Create tables in Postgres
- Copy all data over

---

## Verify Tables Created

After running the backend once, check tables:

```bash
psql -U postgres -d anti_doomscroll -c "\dt"
```

You should see:
- `todos`
- `profiles`

---

## Troubleshooting

**"psql: command not found"**
- Add Postgres to PATH: `export PATH="/opt/homebrew/opt/postgresql@15/bin:$PATH"`

**"database does not exist"**
- Create it: `createdb anti_doomscroll`

**"password authentication failed"**
- Reset password: `psql postgres` then `ALTER USER postgres PASSWORD 'postgres';`
