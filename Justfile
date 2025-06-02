# start all services in the background
start:
  docker compose up -d --remove-orphans

# stop all services
stop:
  docker compose down

# restart web service (or another container)
restart container="web":
  docker compose restart {{ container }}

# run individual specs or all specs if no file is specified
spec file="":
  if [ -z {{ file }} ]; then \
    docker compose run -e RAILS_ENV=test --rm spec bundle exec rspec; \
  else \
    docker compose run -e RAILS_ENV=test --rm spec bundle exec rspec {{ file }}; \
  fi

# run all specs in parallel with configurable workers
pspec workers="4":
  docker compose run -e RAILS_ENV=test -e WORKERS={{ workers }} --rm spec bundle exec rake db:parallel:create db:parallel:prepare
  docker compose run -e RAILS_ENV=test -e WORKERS={{ workers }} --rm spec bundle exec rake parallel_rspec

# run lint for code and erb files
lint:
  docker compose exec web bin/rubocop --autocorrect
  docker compose exec web bin/erb_lint --format compact --lint-all --autocorrect

# setup fresh rails credentials for first-time users
pre-setup:
  docker compose run --rm pre-setup

# run any rails command in the web container
rails +command="console":
  docker compose exec web bundle exec rails {{ command }}

# run any rake command in the web container
rake +command:
  docker compose exec web bundle exec rake {{ command }}

# run any bundle command in the web container
bundle +command:
  docker compose exec web bundle {{ command }}

# tail application logs from the web service
devlog log_lines="1000":
  tail -f -n {{ log_lines }} log/development.log

# tail worker logs from the worker service from STDOUT
bglog log_lines="20":
  @ echo "=====\nNOTE:\n=====\nWorker logs are STDOUT only.\nThis command tails and pull logs from the worker container.\nThis is in-line with how daemons should log: https://github.com/sidekiq/sidekiq/wiki/Logging#logger.\n↓"
  docker compose logs -f --no-log-prefix --tail={{ log_lines }} worker

# attach to the web service (or another container), for pry debugging
attach service="web":
  docker compose attach --detach-keys "ctrl-d" {{ service }}

# open a bash shell in the web service container
shell service="web":
  docker compose exec {{ service }} /bin/bash
