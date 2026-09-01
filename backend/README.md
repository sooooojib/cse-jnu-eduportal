# CSE JnU EduPortal — Backend Application

The authoritative core backend and REST API engine for **CSE JnU EduPortal**, serving the Department of Computer Science & Engineering, Jagannath University (JnU).

---

## 🏛️ Architecture Overview

The backend is engineered using **TypeScript + Express** with a **PostgreSQL** relational database. It adheres strictly to Clean Architecture principles:

- **Auth & RBAC Authority**: Single source of truth for user authentication and role-based authorization (`STUDENT`, `CR`, `TEACHER`, `ADMIN`).
- **Standardized API Envelope**: Uniform JSON response and error contracts across all endpoints.
- **Transactional Integrity**: Concurrency-safe state machines and atomic row-level locks.
- **Relational Integrity**: Foreign keys with purposeful cascade rules and database check constraints.

---

## 📂 Project Structure

```
backend/
├── src/
│   ├── app.ts                         # Express app setup & middleware pipeline
│   ├── server.ts                      # Server bootstrap & graceful lifecycle
│   ├── config/                        # Env validation & database connection pool
│   │   ├── env.ts
│   │   └── database.ts
│   ├── common/
│   │   ├── constants/                 # Roles, enums, error codes, HTTP codes
│   │   ├── errors/                    # AppError hierarchy
│   │   ├── middlewares/               # Auth, RBAC, Validate, Logger, ErrorHandler
│   │   ├── types/                     # Shared TypeScript interfaces & DTOs
│   │   └── utils/                     # Token signers, password hashing, API envelopes
│   ├── modules/
│   │   ├── auth/                      # Authentication, token rotation, signup requests
│   │   ├── health/                    # Health & readiness diagnostics
│   │   └── index.ts                   # Master v1 API router
│   └── storage/
│       └── database/
│           ├── entities/              # 15 Entity interfaces & types
│           ├── migrations/            # 7 SQL migrations for tables, constraints & indexes
│           ├── migration-runner.ts    # Migration runner CLI & engine
│           └── seeds/                 # Initial seed data (Admin, Faculty, CR, Student)
├── tests/
│   ├── setup.ts                       # Test environment setup
│   ├── unit/                          # Password, token, config, validation tests
│   └── integration/                   # Health, Auth, RBAC, and Error handling tests
├── .env.example
├── package.json
└── tsconfig.json
```

---

## 🚀 Quickstart & Local Setup

### 1. Prerequisites
- **Node.js**: v18.0.0 or higher (v22+ recommended)
- **PostgreSQL**: v14.0 or higher
- **npm** or **pnpm** / **yarn**

### 2. Environment Configuration
Copy the template environment file:
```bash
cp .env.example .env
```
Adjust PostgreSQL connection parameters and JWT secrets in `.env`:
```env
PORT=5000
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/cse_jnu_eduportal
JWT_ACCESS_SECRET=your_super_secret_access_jwt_key_at_least_32_characters_long_jnu
JWT_REFRESH_SECRET=your_super_secret_refresh_jwt_key_at_least_32_characters_long_jnu
```

### 3. Install Dependencies
```bash
npm install
```

### 4. Database Migrations & Seeding
Run the database migrations and seed initial users and courses:
```bash
# Check migration status
npm run db:status

# Execute all pending migrations
npm run db:migrate

# Seed baseline users (Admin, Faculty, CR, Student) and courses
npm run db:seed
```

### 5. Start Development Server
```bash
npm run dev
```
The server will start at `http://localhost:5000/api/v1`.

Health check endpoints:
- `GET http://localhost:5000/health`
- `GET http://localhost:5000/api/v1/health`

---

## 🧪 Testing Strategy

Run the comprehensive unit and integration test suite:
```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run test coverage report
npm run test:coverage
```

The test suite validates:
- Configuration validation and defaults
- Password hashing and secure credential generation
- JWT token signing, verification, and expiration
- Zod schema validation middleware and 422 error details
- Health diagnostics and database health probing
- Authentication lifecycle (login, signup requests, token refresh, `/me`)
- Role-Based Access Control (RBAC) guard enforcement
- Centralized error formatting and PostgreSQL error code mapping

---

## 📜 Development Scripts Reference

| Command | Description |
| :--- | :--- |
| `npm run dev` | Starts development server with hot-reload via `ts-node-dev`. |
| `npm run build` | Compiles TypeScript source to production JavaScript in `dist/`. |
| `npm start` | Runs compiled production server from `dist/server.js`. |
| `npm test` | Runs Jest unit and integration test suite. |
| `npm run db:migrate` | Runs all pending SQL migrations in sequence. |
| `npm run db:status` | Shows execution status for all migration files. |
| `npm run db:seed` | Inserts initial seed data into PostgreSQL. |

---

## 🔒 Default Seed Credentials (Development)

| Role | Email | Password |
| :--- | :--- | :--- |
| **Admin** | `admin@cse.jnu.ac.bd` | `Admin@123456` |
| **Faculty** | `teacher@cse.jnu.ac.bd` | `Teacher@123456` |
| **CR** | `cr@cse.jnu.ac.bd` | `Student@123456` |
| **Student** | `student@cse.jnu.ac.bd` | `Student@123456` |
