# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.6
FROM ruby:$RUBY_VERSION-alpine AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    RAILS_LOG_TO_STDOUT="true" \
    RAILS_SERVE_STATIC_FILES="true"

FROM base AS builder

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    curl \
    git \
    pkg-config \
    libpq-dev && \
    rm -rf /var/lib/apt/lists/*

RUN gem install bundler -v 2.5.16 --no-document

COPY Gemfile Gemfile.lock .ruby-version ./

RUN bundle _2.5.16_ config set --local without 'development test' && \
    bundle _2.5.16_ install -j$(nproc) && \
    bundle _2.5.16_ clean --force && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

RUN bundle _2.5.16_ exec rake assets:precompile

RUN bundle _2.5.16_ exec bootsnap precompile app/ lib/

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp public/assets

FROM base AS runtime

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    libjemalloc2 \
    libpq5 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=rails:rails /rails /rails

USER rails:rails

EXPOSE 3000

ENTRYPOINT ["/rails/bin/setup.docker.prod"]

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
