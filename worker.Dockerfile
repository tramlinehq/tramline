ARG RUBY_VERSION=3.3.6

FROM ruby:${RUBY_VERSION}-slim-bullseye

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test"

RUN apt-get update -o Acquire::AllowInsecureRepositories=true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    build-essential \
    libpq-dev \
    curl \
    git \
    libvips \
    pkg-config \
    tzdata \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY .ruby-version .ruby-version
COPY Gemfile Gemfile.lock ./

RUN gem install bundler && bundle install

COPY . .

ENTRYPOINT [ "bash", "-c" ]
CMD ["bundle exec sidekiq"]
