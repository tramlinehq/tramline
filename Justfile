start:
  docker compose up -d

restart container="web":
  docker compose restart {{ container }}

spec:
  docker compose run --rm rspec

lint:
  bin/rubocop --autocorrect

pre-setup:
  docker compose run pre-setup

rails +command="console":
  docker exec -it site-web-1 bundle exec rails {{ command }}

rake +command:
  docker exec -it site-web-1 bundle exec rake {{ command }}

bundle +command:
  docker exec -it site-web-1 bundle {{ command }}

devlog log_lines="1000":
  tail -f -n {{ log_lines }} log/development.log

bglog log_lines="100":
  tail -f -n {{ log_lines }} log/sidekiq.log

attach container="web":
  docker attach --detach-keys "ctrl-d" site-{{ container }}-1

shell container="web":
  docker exec -it site-{{ container }}-1 /bin/bash
