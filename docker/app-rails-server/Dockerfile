# syntax=docker/dockerfile:1

### Stage 1: Builder (Dependencies)
FROM ruby:2.6.6 AS builder
ENV RAILS_ENV=production

# Fix Debian Buster archived repos
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/buster-updates/d' /etc/apt/sources.list

# Install build dependencies
RUN apt-get update -qq && apt-get install -y build-essential nodejs npm

WORKDIR /app

# Install Bundler
RUN gem install bundler:2.1.4

# Cache Ruby Gems
COPY Gemfile Gemfile.lock ./
# Remove frozen in case lock file assumes specific path
RUN bundle config set frozen 'false' && bundle install --jobs 4 --retry 3

# Cache JS Dependencies
COPY package.json yarn.lock ./
RUN npm install yarn -g && yarn install --check-files

### Stage 2: Runner (Final Image)
FROM ruby:2.6.6
ENV RAILS_ENV=production

# Fix Debian Buster archived repos
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/buster-updates/d' /etc/apt/sources.list

# Install Runtime Dependencies
# - nodejs: for webpacker (runtime)
# - docker.io: for controlling sibling containers (docker exec)
# - postgresql-client: for db interaction
RUN apt-get update -qq && apt-get install -y \
    nodejs \
    docker.io \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

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
