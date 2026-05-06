# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.4.9
ARG DISTRO_NAME=trixie
FROM ruby:$RUBY_VERSION-slim-$DISTRO_NAME AS base
ARG DISTRO_NAME

WORKDIR /rails

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips gnupg2 netcat-openbsd && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

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
    RAILS_SERVE_STATIC_FILES=true

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential pkg-config libyaml-dev git && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY .ruby-version Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN GIT_REF=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") && \
    GIT_REF_AT=$(git show -s --format=%cI HEAD 2>/dev/null || date -u +%FT%T%z) && \
    echo "GIT_REF=${GIT_REF}" > /rails/.git_ref && \
    echo "GIT_REF_AT=${GIT_REF_AT}" >> /rails/.git_ref

RUN bundle exec bootsnap precompile app/ lib/

RUN --mount=type=secret,id=RAILS_MASTER_KEY \
    RAILS_MASTER_KEY="$(cat /run/secrets/RAILS_MASTER_KEY)" \
    DESCOPE_PROJECT_ID="build-placeholder" \
    DESCOPE_MANAGEMENT_KEY="build-placeholder" \
    ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd --system --uid 1000 --gid 1000 --create-home --shell /bin/bash rails && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

EXPOSE 3000

ENTRYPOINT ["/rails/bin/setup.docker.prod"]
