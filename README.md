<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="art/tramline-fff-medium.png">
    <img alt="the tramline logo" src="art/tramline-logo-medium.png">
  </picture>
</p>

<h1 align="center">Tramline</h1>

<p align="center">
  <strong>Release apps without drowning in process</strong>
</p>

<p align="center">
  Codify your app's release cycle,<br/>
  deploy builds with increased confidence,<br/>
  and give visibility to the entire organization.<br/>
</p>

<p align="center">
  <a href="https://tramline.app" target="_blank" rel="noopener noreferrer">Website</a>
  ·
  <a href="https://tramline.substack.com" target="_blank" rel="noopener noreferrer">Latest Updates</a>
  ·
  <a href="https://tramline.app/blog" target="_blank" rel="noopener noreferrer">Blog</a>
</p>

<p align="center">
  <a href="https://twitter.com/tramlinehq/" target="_blank" rel="noopener noreferrer">
    <img alt="Twitter Follow" src="https://img.shields.io/twitter/follow/tramlinehq?style=social">
  </a>
  <a href="https://discord.gg/u7VwyvBV2Z" target="_blank" rel="noopener noreferrer">
    <img alt="Discord" src="https://img.shields.io/discord/974284993641725962?style=plastic">
  </a>

  <br/>
  <br/>

  <a href="https://github.com/tramlinehq/site/actions/workflows/ci.yml">
    <img src="https://github.com/tramlinehq/site/actions/workflows/ci.yml/badge.svg?branch=main" />
  </a>

  <a href="https://github.com/testdouble/standard">
    <img src="https://img.shields.io/badge/code_style-standard-brightgreen.svg" />
  </a>

  <a href="CODE_OF_CONDUCT.md">
    <img src="https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg" />
  </a>

  <img alt="GitHub commit activity" src="https://img.shields.io/github/commit-activity/m/tramlinehq/tramline">
</p>

## Features

## Getting Started

The following instructions are for self-hosting Tramline on [Render](https://render.com). The steps should be easily translatable to a Heroku deployment as well. Instructions for other platforms, including a dockerized setup will come in the future.

**Note:** Since Render does not offer background workers under the free plan, you will have to put in your payment details to fully complete this deployment.

You need the bare-minimum of the following to stand up Tramline:

* This repository setup as the primary monolithic backend
* This repository setup as a background worker
* Applelink for communicating with App Store Connect
* Postgres Database
* Redis instance (ideally persistent)

Additionally, you'd need some prep-work around integrations for Tramline to be useful,

* GitHub app
* Slack app
* Google Cloud Storage Account
* Postmark account for sending emails

On a high-level the architecture looks like this,

<figure>
  <img alt="setup architecture" src="art/arch@1x.png" width="90%" />
  <figcaption>High-level setup diagram</figcaption>
</figure>


To kick things off, first clone this repo. This ensures everything that you do is fully under your control.

In case you'd like to run this locally first, please follow [[Development Setup]].

To directly host it, you first need to prep your fork a little bit.

1. Setup rails

```bash
bin/setup.mac
```

2. Generate production credentials

```bash
bin/setup-creds
```

Keep the generated `production.key` safe with you and do not commit this.

3. Update production credentials

After adding the encryption credentials, you will have to fill the following details in `production.yml.enc`. You can do this by running `bin/rails credentials:edit --environment production`.

Use the template below to add the correct information.

* Getting Postmark API token
* Setting Google Cloud Platform keys
* Creating a Slack app
* Creating a GitHub app

For `applelink`, choose any string as your `secret`. We will use this later.

```yaml
active_record_encryption:
  primary_key:
  deterministic_key:
  key_derivation_salt:

dependencies:
  postmark:
    api_token:

  gcp:
    project_id:
    private_key_id:
    private_key: |
    client_email:
    client_id:
    client_x509_cert_url:

integrations:
  slack:
    app_id:
    client_id:
    client_secret:
    signing_secret:
    verification_token:
    scopes: "app_mentions:read,channels:join,channels:manage,channels:read,chat:write,chat:write.public,files:write,groups:read,groups:write,im:read,im:write,usergroups:read,users.profile:read,users:read,users:read.email,commands,usergroups:write"

  applelink:
    iss: "tramline.dev"
    aud: "applelink"
    secret: "any password"

  github:
    app_name:
    app_id:
    private_pem: |


secret_key_base:
```
Save the credentials file and commit your changes. Use this button **from your fork** to kick-off a Render deployment.

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy)

The blueprint will ask for the `RAILS_MASTER_KEY`. Use the contents of `production.key` from the previous step.

Additionally, create a `Secret File` under `applelink > Settings > Environment > Secret Files` called `.env` and update with the following details by putting the applelink secret from the previous step under `AUTH_SECRET`:

```
RACK_ENV=production
WEB_CONCURRENCY=2
MAX_THREADS=1
PORT=3001
AUTH_ISSUER="tramline.dev"
AUTH_AUD="applelink"
AUTH_SECRET=""
SENTRY_DSN=""
```

## Development

#### Setup

For local development on macOS, clone this repository and run the included setup script:

```
bin/setup.mac
```

**Note:** If you already have a previous dev environment that you're trying to refresh, the easiest thing to do is to
drop your database and run setup again.

```bash
rails db:drop
bin/setup.mac
```

Refer to `db/seeds.rb` for credentials on how to login using the seed users.

#### Running

- Place the `master.key` file in the `config` directory.
- Start [ngrok](#webhooks).
- Start PostgreSQL and Redis using [Homebrew services](https://github.com/Homebrew/homebrew-services).
- Finally, run `bin/dev`.

#### Webhooks

Webhooks need access to the application over the Internet and that requires tunneling on the localhost environment. We
use ngrok, and you should run it like this:

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

#### Adding or updating gems

* Use `bundle add <gem>` to add a new gem.
* To update a gem use `bundle update <gem>`.

Using the `bundle add` tool auto-applies
the [pessimistic operator](https://thoughtbot.com/blog/rubys-pessimistic-operator) in the `Gemfile`.
Although `Gemfile.lock` is the correct source of gem versions, specifying the pessimistic operator makes for a simpler
and safer update path through bundler for future users.

Doing this for development/test groups is optional.

#### SSL

We use SSL locally and certificates are also generated as part of the setup script. It's recommended to
use https://tramline.local.gd:3000.

This is the default `HOST_NAME` that can be changed via `.env.development` if necessary.

#### Letter Opener

All e-mails are caught and can be viewed [here](https://tramline.local.gd:3000/letter_opener).

#### Sidekiq

The dashboard for all background jobs can be viewed [here](https://tramline.local.gd:3000/sidekiq).

#### Flipper

All feature-flags are managed through flipper. The UI can be viewed [here](https://tramline.local.gd:3000/flipper).

## Contributing

We are early and listening. We would <3 feedback in any of the following ways:

- Join our [Discord](https://discord.com/invite/u7VwyvBV2Z) and ask us questions and/or let us know your thoughts
- Submit a [feature request or bug report](https://github.com/tramlinehq/tramline/issues/new/choose)
- Open a PR (see our instructions on local development here.)

## Open-source vs. paid

This repo is available under the [MIT expat](/LICENSE) license, except for the `ee` directory (which has it's
license [here](https://github.com/tramlinehq/tramline/blob/main/ee/LICENSE)) if applicable.

There are currently no EE-exclusive features in the repository.
