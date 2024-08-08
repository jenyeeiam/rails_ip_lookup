# Use the official Ruby image as a parent image
FROM ruby:3.3

# Set environment variables
ENV RAILS_ENV=production
ENV NODE_ENV=production

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs \
  yarn \
  wget \
  gnupg \
  lsb-release

# Add PostgreSQL repository
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -

# Update package list and install PostgreSQL client and PostGIS
RUN apt-get update && apt-get install -y \
  postgresql-client-14 \
  postgis \
  postgresql-14-postgis-3 \
  libpq-dev \
  postgis

# Set the working directory
WORKDIR /app

# Copy the Gemfile and Gemfile.lock into the container
COPY Gemfile* ./

# Install production gems
RUN bundle config set --local without 'development test' && \
    bundle install

# Copy the rest of the application code
COPY . .

# Copy the master key
COPY config/master.key /app/config/master.key

# Precompile assets
RUN SECRET_KEY_BASE=dummy bundle exec rake assets:precompile

# Expose port 3000 to the Docker host
EXPOSE 3000

# Copy the entrypoint script into the image
COPY entrypoint.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["entrypoint.sh"]

# Command to run the application
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]