#!/bin/bash
set -e

# Give Postgres a moment to start
sleep 5

# Create the database if it doesn't exist
PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USERNAME" -d "$DATABASE_NAME" -c "CREATE EXTENSION IF NOT EXISTS postgis;"


# Wait for the database to be ready
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USERNAME" -d "$DATABASE_NAME" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - executing command"

# Ensure gems are installed
echo "Running bundle install..."
bundle install --quiet

# Run database migrations
echo "Running database migrations..."
bundle exec rake db:migrate

# Import fake data (only if it hasn't been imported before)
if [ ! -f /app/.data_imported ]; then
  echo "Importing geolocation data..."
  bundle exec rake geolocations:import
  touch /app/.data_imported
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile)
echo "Starting main process..."
exec "$@"