# README

The primary orchestration and frontend monolith.

## Setup

### Ruby

The recommended ruby version manager is [asdfvm](https://asdf-vm.com). But [rbenv](https://github.com/rbenv/rbenv) should also work well.

* Follow this [guide](https://asdf-vm.com/guide/getting-started.html#_3-install-asdf) to install asdfvm.
* Follow this [guide](https://github.com/rbenv/rbenv#installation) to install rbenv.

Install `ruby 3.1.0`,

##### rbenv

```
ruby install 3.1.0
```

##### asdfvm

```
asdf install ruby 3.1.0
```

### Rails

Checking into the root directory should correctly activate your ruby version. Confirm this by running,

```
❯ ruby --version
ruby 3.1.0p0 (2021-12-25 revision fb4df44d16) [arm64-darwin21]
```

After this, install `bundler` for bootstrapping rails and our dependencies.

```
gem install bundler
```

Now run,

```
bundle install
```

### Database

Make sure you have Postgres 14 running. On the mac, [Postgres.app](https://postgresapp.com) is a handy way of managing pg versions.

## Developer Notes

### App Settings

All admins should be able to access the settings page where general app-level configurations are tweaked at http://localhost:3000/admin/settings.

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