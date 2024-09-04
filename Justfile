start:
  bin/dev

goto session="console":
  overmind connect {{session}}

spec:
  bundle exec rspec

lint:
  bin/rubocop --autocorrect

devlog log_lines="1000":
  tail -f -n {{ log_lines }} log/development.log

bglog log_lines="100":
  tail -f -n {{ log_lines }} log/sidekiq.log
