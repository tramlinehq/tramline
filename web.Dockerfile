ARG RUBY_VERSION=3.3.6

FROM ruby:${RUBY_VERSION}-slim-bullseye

ENV RAILS_ENV=production \
    NODE_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    BUNDLE_DEPLOYMENT=true \
    BUNDLE_WITHOUT="development:test"

RUN apt-get update -o Acquire::AllowInsecureRepositories=true && \
    apt-get install -y --no-install-recommends --allow-unauthenticated \
    build-essential \
    libpq-dev \
    nodejs \
    curl \
    git \
    pkg-config \
    libvips \
    tzdata \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY .ruby-version .ruby-version
COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

# NOTE: assets:precompile is not needed to be done in here, will be done in Kamal
# RUN bundle exec rake assets:precompile

ENTRYPOINT [ "bash", "-c" ]
CMD ["bundle exec puma -C config/puma.rb"]
