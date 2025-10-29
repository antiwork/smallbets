# syntax = docker/dockerfile:1

# Make sure it matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=3.3.1
FROM ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM --platform=$TARGETPLATFORM base as build

# Install packages need to build gems and Node.js for Vite
RUN apt-get update -qq && \
    apt-get install -y build-essential git pkg-config nodejs npm

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# Install Node dependencies and build assets with Vite
RUN npm install && \
    npm run build

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN mkdir -p /rails/storage/logs
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Configure environment defaults
ENV HTTP_IDLE_TIMEOUT=60
ENV HTTP_READ_TIMEOUT=300
ENV HTTP_WRITE_TIMEOUT=300

# Install packages needed to run the application
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libsqlite3-0 libvips curl ffmpeg redis git sqlite3 awscli cron nano dialog && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Set version and revision
ARG APP_VERSION
ENV APP_VERSION=$APP_VERSION
ARG GIT_REVISION
ENV GIT_REVISION=$GIT_REVISION

# Expose app ports
EXPOSE 3000

COPY script/admin/full-backup /etc/cron.daily/
COPY script/admin/db-backup /etc/cron.hourly/

# Add health check to verify the application is running
HEALTHCHECK --interval=5s --timeout=3s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000/up || exit 1

# Start the server by default, this can be overwritten at runtime
CMD service cron start && bin/configure && bin/boot