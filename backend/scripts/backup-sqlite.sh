#!/usr/bin/env bash
# Copies the SQLite DB to backups/monity-YYYYMMDD-HHMMSS.sqlite next to the DB file.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_PATH="${DATABASE_PATH:-$ROOT/monity.sqlite}"
if [[ ! -f "$DB_PATH" ]]; then
  echo "Database file not found: $DB_PATH"
  exit 1
fi
DEST_DIR="$(dirname "$DB_PATH")/backups"
mkdir -p "$DEST_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
cp "$DB_PATH" "$DEST_DIR/monity-$STAMP.sqlite"
echo "Backed up to $DEST_DIR/monity-$STAMP.sqlite"
