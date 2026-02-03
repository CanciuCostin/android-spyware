# syntax=docker/dockerfile:1

### Stage 1: Builder (Dependencies)
FROM ruby:2.6.6 AS builder
ENV RAILS_ENV=production

# Fix Debian Buster + Install build dependencies (SonarQube: Minimize layers)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i '/buster-updates/d' /etc/apt/sources.list \
    && apt-get update -qq \
    && apt-get install -y build-essential nodejs npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Cache Ruby Gems & JS Dependencies (SonarQube: Minimize layers)
COPY Gemfile Gemfile.lock package.json yarn.lock ./
RUN gem install bundler:2.1.4 \
    && bundle config set frozen 'false' \
    && bundle install --jobs 4 --retry 3 \
    && npm install yarn -g \
    && yarn install --check-files \
    && rm -rf /tmp/* /var/tmp/*

### Stage 2: Runner (Final Image)
FROM ruby:2.6.6
ENV RAILS_ENV=production

# Fix Debian Buster archived repos + Install Runtime Dependencies
# (SonarQube: Combined RUN commands to reduce layers)
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list \
    && sed -i '/buster-updates/d' /etc/apt/sources.list \
    && apt-get update -qq \
    && apt-get install -y --no-install-recommends \
        nodejs \
        docker.io \
        postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

WORKDIR /app

# Copy dependencies from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder /app/node_modules ./node_modules

# Copy Application Code
COPY . .

# Precompile assets (optional for dev, mandatory for prod)
# RUN bundle exec rake assets:precompile

# Expose Rails Port
EXPOSE 3000

# Default Command
CMD ["rails", "server", "-b", "0.0.0.0"]
