# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.6
ARG BUNDLER_VERSION=2.4.22
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y git tzdata curl libjemalloc2 libvips sqlite3 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    DESCOPE_PROJECT_ID=dummy_project_id \
    DESCOPE_MANAGEMENT_KEY=dummy_management_key \
    RAILS_SERVE_STATIC_FILES=true

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

# Precompile bootsnap code for faster boot times
# RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/setup.docker.prod"]
