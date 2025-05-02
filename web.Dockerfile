ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION}-alpine

ARG BUNDLER_VERSION=2.6.7

ENV RAILS_ENV=production \
    NODE_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test"

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
    bundle _"$BUNDLER_VERSION"_ install

COPY . .

# Temporarily disable master key requirement and stub credentials for asset precompilation
RUN cp config/environments/production.rb config/environments/production.rb.orig && \
    sed -i 's/config.require_master_key = true/config.require_master_key = false/' config/environments/production.rb && \
    sed -i "s/Rails.application.credentials.dependencies.postmark.api_token/'dummy_token_for_precompilation'/" config/environments/production.rb && \
    bundle config set deployment true && \
    DESCOPE_PROJECT_ID=dummy_project_id \
    DESCOPE_MANAGEMENT_KEY=dummy_management_key \
    SECRET_KEY_BASE=dummy_key_for_precompilation \
    bundle exec rake assets:precompile && \
    bundle exec rake assets:clean && \
    mv config/environments/production.rb.orig config/environments/production.rb

ENTRYPOINT ["sh", "-c"]

CMD ["if [ \"$KAMAL_ROLE\" = 'worker' ]; then bundle exec sidekiq; else bundle exec puma -C config/puma.rb; fi"]
