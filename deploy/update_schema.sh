#!/bin/sh
set -e

>&2

if [ -n "$POSTGRES_PASSWORD_FILE" ] && [ -f "$POSTGRES_PASSWORD_FILE" ]; then
	POSTGRES_PASSWORD="$(cat "$POSTGRES_PASSWORD_FILE")"
fi

DATABASE_HOST="${DATABASE_HOST:-localhost}"
DATABASE_PORT="${DATABASE_PORT:-5432}"

database="rss-aggre"

url="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DATABASE_HOST}:${DATABASE_PORT}/${database}"

echo "Executing database migration with goose"

cd /schema && goose postgres "$url" up
