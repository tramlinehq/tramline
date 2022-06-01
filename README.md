# README

The primary orchestration and frontend monolith.

## Development Setup

We have a `bin/setup` script that does most of the work of getting things setup, but you need a few things in place first. If you are on a Mac, install:

```bash
brew install rbenv ruby-build redis postgresql@14
```

For local development, clone the git repository and run the setup script included:

```bash
git clone git@github.com:tramlinehq/site.git
cd site
bin/setup.mac
```

Note: If you already have a previous dev environment you're trying to refresh, it's easiest to drop your database run setup again.

```bash
rails db:drop
bin/setup.mac
```

Refer to `db/seeds.rb` for credentials on how to login using the seed users.

## Developer Notes

### Letter Opener

All e-mails are caught and can be viewed at http://localhost:3000/letter_opener.

### Sidekiq

The dashboard for all background jobs can be viewed at http://localhost:3000/sidekiq.

### Flipper

All feature-flags are managed through flipper. The UI can be viewed at: http://localhost:3000/flipper. 

### Adding or updating gems

* Use `bundle add <gem>` to add a new gem.
* To update a gem use `bundle update <gem>`.

Using the `bundle add` tool auto-applies the [pessimistic operator](https://thoughtbot.com/blog/rubys-pessimistic-operator) in the `Gemfile`. Although `Gemfile.lock` is the correct source of gem versions, specifying the pessimistic operator makes for a simpler and safer update path through bundler for future users.

Doing this for development/test groups is optional.
