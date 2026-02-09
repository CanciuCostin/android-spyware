# syntax=docker/dockerfile:1
# cspell:words libpq tzdata pids MALLOC

### Stage 1: Builder (Dependencies & Assets)
FROM ruby:3.3.0-slim-bookworm AS builder
ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test

# Install build dependencies
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git \
        libpq-dev \
        nodejs \
        npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

# Install dependencies first (better layer caching)
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.5.5 \
    && bundle config set --local frozen 'false' \
    && bundle config set --local deployment 'true' \
    && bundle config set --local without 'development test' \
    && bundle install --jobs 4 --retry 3 \
    && rm -rf /usr/local/bundle/cache/*.gem

# Install Node dependencies (using modern Yarn or NPM)
COPY package.json yarn.lock* ./
RUN npm install --global yarn --no-audit --no-fund \
    && if [ -f yarn.lock ]; then yarn install --production --frozen-lockfile; else npm install --production; fi \
    && yarn cache clean || true

# Copy application code
COPY . .

# Precompile assets in builder stage
RUN SECRET_KEY_BASE=dummy_for_build bundle exec rails assets:precompile \
    && rm -rf node_modules tmp/cache

### Stage 2: Runtime (Production-Optimized)
FROM ruby:3.3.0-slim-bookworm
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    MALLOC_ARENA_MAX=2

# Install only runtime dependencies
RUN apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libpq5 \
        tzdata \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && groupadd -r rails --gid=1000 \
    && useradd -r -g rails --uid=1000 --home-dir=/app --shell=/bin/bash rails

WORKDIR /app

# Copy bundled gems from builder
COPY --from=builder --chown=rails:rails /usr/local/bundle /usr/local/bundle

# Copy application with precompiled assets
COPY --from=builder --chown=rails:rails /app /app

# Create runtime directories
RUN mkdir -p tmp/pids tmp/cache tmp/sockets log files/payloads files/dumps storage \
    && chown -R rails:rails /app

# Switch to non-root user (Security Best Practice)
USER rails

# Expose Rails Port
EXPOSE 3000

# Enhanced health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/health/live || exit 1

# Default Command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
