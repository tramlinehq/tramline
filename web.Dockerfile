ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION}-alpine AS builder

ARG BUNDLER_VERSION=2.4.22

ENV RAILS_ENV=production \
    NODE_ENV=production \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test" \
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

WORKDIR /app

COPY .ruby-version Gemfile Gemfile.lock ./

RUN gem install bundler -v "$BUNDLER_VERSION" && \
    bundle _"$BUNDLER_VERSION"_ install && \
    find /usr/local/bundle -type f -name "*.c" -delete && \
    find /usr/local/bundle -type f -name "*.o" -delete

COPY . .

# Temporarily disable master key requirement and stub credentials for asset precompilation
RUN cp config/environments/production.rb config/environments/production.rb.orig && \
    sed -i 's/config.require_master_key = true/config.require_master_key = false/' config/environments/production.rb || true && \
    sed -i "s/Rails.application.credentials.dependencies.postmark.api_token/'dummy_token_for_pre_compilation'/" config/environments/production.rb || true && \
    bundle config set deployment true && \
    bundle exec rake assets:precompile --trace && \
    mv config/environments/production.rb.orig config/environments/production.rb && \
    rm -rf /app/tmp/cache node_modules

# Final stage - only include what's needed for runtime
FROM ruby:${RUBY_VERSION}-alpine

ENV RAILS_ENV=production \
    NODE_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

RUN apk add --no-cache \
    postgresql-client \
    tzdata \
    vips \
    nodejs

WORKDIR /app

# Copy gems from builder
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy app with precompiled assets
COPY --from=builder /app /app

ENTRYPOINT ["sh", "-c"]

CMD ["if [ \"$KAMAL_ROLE\" = 'worker' ]; then bundle exec sidekiq; else bundle exec puma -C config/puma.rb; fi"]
