start:
  docker compose up -d --remove-orphans

stop:
  docker compose down

restart container="web":
  docker compose restart {{ container }}

spec file="":
  if [ -z {{ file }} ]; then \
    docker compose run --rm spec; \
  else \
    docker compose run --rm spec bundle exec rspec {{ file }}; \
  fi

lint:
  docker compose exec web bin/rubocop --autocorrect
  docker compose exec web bin/erb_lint --format compact --lint-all --autocorrect

pre-setup:
  docker compose run --rm pre-setup

rails +command="console":
  docker compose exec web bundle exec rails {{ command }}

rake +command:
  docker compose exec web bundle exec rake {{ command }}

bundle +command:
  docker compose exec web bundle {{ command }}

devlog log_lines="1000":
  tail -f -n {{ log_lines }} log/development.log

bglog log_lines="20":
  @ echo "=====\nNOTE:\n=====\nWorker logs are STDOUT only.\nThis command tails and pull logs from the worker container.\nThis is in-line with how daemons should log: https://github.com/sidekiq/sidekiq/wiki/Logging#logger.\n↓"
  docker compose logs -f --no-log-prefix --tail={{ log_lines }} worker

attach service="web":
  docker compose attach --detach-keys "ctrl-d" {{ service }}

shell service="web":
  docker compose exec {{ service }} /bin/bash
