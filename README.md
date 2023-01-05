# site ![ci](https://github.com/tramlinehq/site/actions/workflows/ci.yml/badge.svg)

The primary orchestration and frontend monolith.

## Development Setup

For local development on macOS, clone this repository and run the included setup script:

```
bin/setup.mac
```

Note: If you already have a previous dev environment that you're trying to refresh, the easiest thing to do is to drop your database and run setup again.

```bash
rails db:drop
bin/setup.mac
```

Refer to `db/seeds.rb` for credentials on how to login using the seed users.

## Running the development environment
- Place the `master.key` file in the `config` directory. You can get this file from our Google Cloud Storage bucket.
- Start [ngrok](#webhooks)
- Start PostgreSQL and Redis using [Homebrew services](https://github.com/Homebrew/homebrew-services)
- Finally, run `bin/dev`

## Developer Notes

### Webhooks

Webhooks need access to the application over the Internet and that requires tunneling on the localhost environment. We use ngrok, and you should run it like this:

```bash
ngrok http https://localhost:3000
```

If you'd like to use the custom DNS tunnel, add the following to your ngrok config file,

```yaml
version: "2"
authtoken: # put your authtoken
region: in
tunnels:
  tramline_dev:
    proto: http
    hostname: # add the tunnel hostname
    addr: https://localhost:3000
```

You can run this configured tunnel via

```bash
ngrok start tramline_dev
```

or through the `Procfile.dev`

### Adding or updating gems

* Use `bundle add <gem>` to add a new gem.
* To update a gem use `bundle update <gem>`.

Using the `bundle add` tool auto-applies the [pessimistic operator](https://thoughtbot.com/blog/rubys-pessimistic-operator) in the `Gemfile`. Although `Gemfile.lock` is the correct source of gem versions, specifying the pessimistic operator makes for a simpler and safer update path through bundler for future users.

Doing this for development/test groups is optional.

### SSL

We use SSL locally and certificates are also generated as part of the setup script. It's recommended to use https://tramline.local.gd:3000.

This is the default `HOST_NAME` that can be changed via `.env.development` if necessary.

### Letter Opener

All e-mails are caught and can be viewed at https://tramline.local.gd:3000/letter_opener.

### Sidekiq

The dashboard for all background jobs can be viewed at https://tramline.local.gd:3000/sidekiq.

### Flipper

All feature-flags are managed through flipper. The UI can be viewed at: https://tramline.local.gd:3000/flipper.
