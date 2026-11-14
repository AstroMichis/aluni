#!/bin/bash
# Runs once, when the Postgres data directory is first initialized (official
# image, /docker-entrypoint-initdb.d). Creates the least-privilege role the
# app connects as and hands it ownership of the app database, so migrations
# work without superuser. The superuser (`postgres`) is left to backups.
set -euo pipefail

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v app_password="$APP_DB_PASSWORD" <<-'SQL'
	CREATE ROLE aluni_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD :'app_password';
	ALTER DATABASE aluni_production OWNER TO aluni_app;
	ALTER SCHEMA public OWNER TO aluni_app;
SQL
