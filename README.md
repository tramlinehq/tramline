# README

The primary orchestration and frontend monolith.

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