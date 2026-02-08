# syntax=docker/dockerfile:1

### Stage 1: Builder (Dependencies & Assets)
FROM ruby:2.6.6 AS builder
ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT=development:test

# Fix Debian Buster archives + Install build dependencies
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i '/buster-updates/d' /etc/apt/sources.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        nodejs \
        npm \
        git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

# Install dependencies first (better layer caching)
COPY Gemfile Gemfile.lock ./
RUN gem install bundler:2.1.4 \
    && bundle config set --local frozen 'false' \
    && bundle config set --local deployment 'true' \
    && bundle config set --local without 'development test' \
    && bundle install --jobs 4 --retry 3 \
    && rm -rf /usr/local/bundle/cache/*.gem \
    && find /usr/local/bundle/gems/ -name "*.c" -delete \
    && find /usr/local/bundle/gems/ -name "*.o" -delete

# Install Node dependencies
COPY package.json yarn.lock ./
RUN npm install --global yarn@1.22.19 --no-audit --no-fund \
    && yarn install --production --frozen-lockfile \
    && yarn cache clean \
    && rm -rf /tmp/* /var/tmp/* ~/.npm ~/.yarn

# Copy application code
COPY . .

# Precompile assets in builder stage
RUN SECRET_KEY_BASE=dummy bundle exec rails assets:precompile \
    && rm -rf node_modules tmp/cache

### Stage 2: Runtime (Production-Optimized)
FROM ruby:2.6.6-slim
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=1 \
    RAILS_SERVE_STATIC_FILES=1 \
    MALLOC_ARENA_MAX=2

# Fix Debian Buster + Install only runtime dependencies
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i '/buster-updates/d' /etc/apt/sources.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        curl \
        ca-certificates \
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

# Enhanced health check with new endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/health/live || exit 1

# Entrypoint script for initialization
ENTRYPOINT []

# Default Command
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
