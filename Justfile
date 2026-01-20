# Helper to get docker compose command with worktree override if applicable
# In a worktree, .git is a file (not a directory), so we use the worktree compose override
_is_worktree := `if [ -f .git ]; then echo "true"; else echo "false"; fi`

# Generate unique port number based on worktree name hash
# Uses CRC32 to generate a consistent hash, then maps to port range 3001-3999
_port_offset := `printf '%s' "$(basename $(pwd))" | cksum | cut -d' ' -f1 | awk '{print ($1 % 999) + 1}'`
_web_port := `if [ -f .git ]; then echo $((3000 + $(printf '%s' "$(basename $(pwd))" | cksum | cut -d' ' -f1 | awk '{print ($1 % 999) + 1}'))); else echo "3000"; fi`

# Build the compose command with environment variables
_worktree_name := `basename $(pwd)`
_compose_cmd := if _is_worktree == "true" { "WEB_PORT=" + _web_port + " WORKTREE_NAME=" + _worktree_name + " docker compose -f compose.yml -f compose.worktree.yml --env-file .env.development" } else { "docker compose --env-file .env.development" }

# show the ports and URLs assigned to this worktree
ports:
  @echo "Worktree: {{ `basename $(pwd)` }}"
  @echo "Web port: {{ _web_port }}"
  @echo ""
  @echo "Local URL: https://localhost:{{ _web_port }}"
  @echo "Tunnel URL: $(bin/get-tunnel-url)"

# start all services in the background
start:
  {{ _compose_cmd }} up -d --remove-orphans

# stop all services
stop:
  {{ _compose_cmd }} down

# restart web service (or another container)
restart container="web":
  {{ _compose_cmd }} restart {{ container }}

# run individual specs or all specs if no file is specified
spec file="":
  if [ -z {{ file }} ]; then \
    {{ _compose_cmd }} run -e RAILS_ENV=test --rm spec bundle exec rspec; \
  else \
    {{ _compose_cmd }} run -e RAILS_ENV=test --rm spec bundle exec rspec {{ file }}; \
  fi

# run all specs in parallel with configurable workers
pspec workers="4":
  {{ _compose_cmd }} run -e RAILS_ENV=test -e WORKERS={{ workers }} --rm spec bundle exec rake db:parallel:create db:parallel:prepare
  {{ _compose_cmd }} run -e RAILS_ENV=test -e WORKERS={{ workers }} --rm spec bundle exec rake parallel_rspec

# run lint for code and erb files
lint:
  {{ _compose_cmd }} exec web bin/rubocop --autocorrect
  {{ _compose_cmd }} exec web bin/erb_lint --format compact --lint-all --autocorrect

# setup fresh rails credentials for first-time users
pre-setup:
  {{ _compose_cmd }} run --rm pre-setup

# run any rails command in the web container
rails +command="console":
  {{ _compose_cmd }} exec web bundle exec rails {{ command }}

# run any rake command in the web container
rake +command:
  {{ _compose_cmd }} exec web bundle exec rake {{ command }}

# run any bundle command in the web container
bundle +command:
  {{ _compose_cmd }} exec web bundle {{ command }}

# tail application logs from the web service
devlog log_lines="1000":
  tail -f -n {{ log_lines }} log/development.log

# tail worker logs from the worker service from STDOUT
bglog log_lines="20":
  @ echo "=====\nNOTE:\n=====\nWorker logs are STDOUT only.\nThis command tails and pull logs from the worker container.\nThis is in-line with how daemons should log: https://github.com/sidekiq/sidekiq/wiki/Logging#logger.\n↓"
  {{ _compose_cmd }} logs -f --no-log-prefix --tail={{ log_lines }} worker

# attach to the web service (or another container), for pry debugging
attach service="web":
  {{ _compose_cmd }} attach --detach-keys "ctrl-d" {{ service }}

# open a bash shell in the web service container
shell service="web":
  {{ _compose_cmd }} exec {{ service }} /bin/bash
