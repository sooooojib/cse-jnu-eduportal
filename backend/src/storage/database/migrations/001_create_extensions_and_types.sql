-- Migration: 001_create_extensions_and_types.sql
-- Description: Enables UUID extension and baseline database configuration

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
