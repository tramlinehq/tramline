lines := "1000"

cop:
  bundle exec rubocop --autocorrect

spec:
  bundle exec rspec

dev:
  bin/dev

serverlog:
  tail -f -n {{ lines }} log/development.log

workerlog:
  tail -f -n {{ lines }} log/sidekiq.log
