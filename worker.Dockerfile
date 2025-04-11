ARG RUBY_VERSION=3.3.6
FROM ruby:${RUBY_VERSION}-alpine AS builder

ARG BUNDLER_VERSION=2.6.7
WORKDIR /app

RUN apk add --no-cache build-base postgresql-dev

COPY .ruby-version Gemfile Gemfile.lock ./
RUN gem install bundler -v "$BUNDLER_VERSION" && \
    bundle _"$BUNDLER_VERSION"_ install --jobs=4

FROM ruby:${RUBY_VERSION}-alpine

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test"

RUN apk add --no-cache postgresql-dev

WORKDIR /app
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY . .

ENTRYPOINT ["sh", "-c"]
CMD ["bundle exec sidekiq"]
