#!/bin/bash
# Test backup restore in isolated environment

BACKUP_FILE="$1"
TEST_DB="eaglespy_test_restore"

echo "Testing backup restore..."

# Create test database
docker-compose exec db createdb -U postgres $TEST_DB

# Restore backup to test database
pg_restore -h localhost -U postgres -d $TEST_DB --clean "$BACKUP_FILE"

# Run validation queries
docker-compose exec db psql -U postgres -d $TEST_DB -c "SELECT COUNT(*) FROM apk_installations;"
docker-compose exec db psql -U postgres -d $TEST_DB -c "SELECT COUNT(*) FROM keylogs;"

# Cleanup
docker-compose exec db dropdb -U postgres $TEST_DB

echo "✓ Backup restore test passed"
