ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION}-alpine

ARG BUNDLER_VERSION=2.6.7
ARG RAILS_MASTER_KEY

ENV RAILS_ENV=production \
    NODE_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test" \
    RAILS_MASTER_KEY=${RAILS_MASTER_KEY}

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
