
# ARG RUBY_VERSION=3.3.6
# FROM ruby:${RUBY_VERSION}

# ARG BUNDLER_VERSION=2.6.7

# ENV RAILS_ENV=staging-gcp \
#     NODE_ENV=production \
#     RAILS_LOG_TO_STDOUT=true \
#     RAILS_SERVE_STATIC_FILES=true \
#     BUNDLE_DEPLOYMENT=true \
#     BUNDLE_WITHOUT="development:test"

# # Install system dependencies
# RUN apt-get update -qq && \
#     apt-get install -y --no-install-recommends \
#     build-essential \
#     curl \
#     git \
#     libpq-dev \
#     nodejs \
#     tzdata \
#     libvips \
#     pkg-config \
#     ca-certificates && \
#     rm -rf /var/lib/apt/lists/*

# WORKDIR /app

# COPY .ruby-version Gemfile Gemfile.lock ./
# RUN gem install bundler -v "$BUNDLER_VERSION" && \
#     bundle _"$BUNDLER_VERSION"_ install

# COPY . .

# ENTRYPOINT ["sh", "-c"]

# CMD ["if [ \"$KAMAL_ROLE\" = 'worker' ]; then bundle exec sidekiq; else bundle exec puma -C config/puma.rb; fi"]

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

RUN bundle config set deployment true && \
    bundle exec rake assets:precompile && \
    bundle exec rake assets:clean

ENTRYPOINT ["sh", "-c"]

CMD ["if [ \"$KAMAL_ROLE\" = 'worker' ]; then bundle exec sidekiq; else bundle exec puma -C config/puma.rb; fi"]
