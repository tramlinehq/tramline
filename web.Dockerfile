# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.6
ARG DISTRO_NAME=bookworm
FROM ruby:$RUBY_VERSION-slim-$DISTRO_NAME AS base
ARG DISTRO_NAME

WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips gnupg2 libnss3-tools git netcat-openbsd && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install PostgreSQL dependencies
ARG PG_MAJOR=14
RUN curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    gpg --dearmor -o /usr/share/keyrings/postgres-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgres-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt/" \
    $DISTRO_NAME-pgdg main $PG_MAJOR | tee /etc/apt/sources.list.d/postgres.list > /dev/null
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=tmpfs,target=/var/log \
    apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get -yq dist-upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    libpq-dev \
    postgresql-client-$PG_MAJOR

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    DESCOPE_PROJECT_ID=dummy_project_id \
    DESCOPE_MANAGEMENT_KEY=dummy_management_key \
    RAILS_SERVE_STATIC_FILES=true

# Throw-away build stage to reduce size of final image
FROM base AS build

ARG BUNDLER_VERSION=2.4.22

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential pkg-config libyaml-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
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
RUN RAILS_MASTER_KEY=dummy DISABLE_SPRING=1 SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Final stage for app image
FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN git config --global --add safe.directory '*'

RUN groupadd --system --gid 1000 rails || true && \
    useradd --system --uid 1000 --gid 1000 --create-home --shell /bin/bash rails || true && \
    chown -R 1000:1000 /rails

USER 1000:1000

EXPOSE 3000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/setup.docker.prod"]
