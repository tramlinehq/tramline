ARG RUBY_VERSION=3.3.6
ARG BUNDLER_VERSION=2.4.22
FROM ruby:${RUBY_VERSION}-alpine AS builder

WORKDIR /rails

ENV RAILS_ENV="production" \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    DESCOPE_PROJECT_ID=dummy_project_id \
    DESCOPE_MANAGEMENT_KEY=dummy_management_key \
    SECRET_KEY_BASE=dummy_key_for_precompilation \
    RAILS_SERVE_STATIC_FILES=true

RUN apk add --no-cache \
    build-base \
    curl \
    git \
    postgresql-dev \
    nodejs \
    tzdata \
    vips

# Throw-away build stage to reduce size of final image
FROM base AS build

COPY .ruby-version Gemfile Gemfile.lock ./

RUN gem install bundler -v "$BUNDLER_VERSION" && \
    bundle _"$BUNDLER_VERSION"_ config set --local without development && \
    bundle _"$BUNDLER_VERSION"_ install && \
    find /usr/local/bundle -type f -name "*.c" -delete && \
    find /usr/local/bundle -type f -name "*.o" -delete

# Copy application code
COPY . .

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

ENV RAILS_ENV=production \
    NODE_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_PATH="/usr/local/bundle"

RUN apk add --no-cache \
    postgresql-client \
    tzdata \
    vips \
    nodejs

# Copy built artifacts: gems, application
COPY --from=builder "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=builder /rails /rails

ENTRYPOINT ["/app/bin/setup.docker.prod"]
