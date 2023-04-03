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

## Features ✨

### Release dashboards

A centralized dashboard to monitor and control all your mobile releases, that gives visibility into the release process to all stakeholders.

### Release trains 

Using the release train model, you can setup different types of releases as separate trains comprising of different steps. For e.g. your production release train can look completely different from the release train that does frequent internal deploys.

### Integrations

Connect with all the [essential tools](https://www.tramline.app/integrations) you use during your release cycle: version control, notifications, CI/CD (build) servers, distribution services, and both App Store and Play Store.

### Automations

Save time and reduce human error across the board by automating release-specific chores. For e.g. 

- Create a new release branch for every release
- Create and merge release-specific branches, as determined by your branching strategy 
- Submit build to the Store only after explicit approval 
- Tag the final release build commit 
- Don't allow starting a new release unless previous release-specific commits have landed in the working branch

### Analytics

Track and visualize release-specific metadata that you need to make informed decisions: release frequency, build times, review times, etc. 


## How to set it up yourself ⚙️

These steps assume setting it up on [Render](https://render.com) only. However, the instructions are standard enough to be adapted for a [Heroku](https://heroku.com) deployment or even bare-metal. A Dockerized setup is in the works and will come shortly.

> **Note:** Since Render does not offer background workers under the free plan, you will have to put in your payment details to fully complete this deployment.

### Requirements

At minimum, you'll need the following to get Tramline up and running:

- This repository set up as the primary monolithic backend
- This repository set up as a background worker
- Postgres database
- Redis, preferably persistent

You'll also need to set up integrations for Tramline to be useful:

* [Postmark API token](https://postmarkapp.com/support/article/1008-what-are-the-account-and-server-api-tokens)
* [Google Cloud Service Account](https://kinsta.com/knowledgebase/google-cloud-storage-backup/#create-a-service-account)
* [Creating a Slack app](https://api.slack.com/authentication/basics)
* [Creating a GitHub app](https://docs.github.com/en/apps/creating-github-apps/creating-github-apps/creating-a-github-app)

### Setting up integration apps

The guides above should help you setup the OAuth apps as necessary. They may ask you to fill up a redirect URL, this URL should be updated with the final DNS after everything is setup towards the end.

### Google Cloud Platform

We need to setup GCP for storing builds in Tramline. After creating your service account as mentioned above, please create a GCS bucket named `artifact-builds-prod` to host your builds.

### Setting up Tramline

The deployment architecture looks like this:

<figure>
  <img alt="setup architecture" src="art/overall-arch@1x.png" width="90%" />
</figure>

To begin, first clone this repo. This ensures everything that you do is fully under your control.

In case you'd like to run this locally first, please follow the [local development instructions](#local-development-%EF%B8%8F).

To host Tramline directly, you'll need to prep your fork:

### Set up Rails

```bash
bin/setup.mac
```

### Generate production credentials and follow the instructions

```bash
bin/setup.creds -e prod
```

Keep the `production.key` file safe and don't commit it! 

### Update production credentials

After adding the encryption credentials, fill in the following details for the integrations in `production.yml.enc` by running `bin/rails credentials:edit --environment production`.

Follow the links mentioned earlier to setup the bare-minimum integrations.

For `applelink`, choose any string as your `secret`. We will use this later.

Use the following template:

```yaml
active_record_encryption:
  primary_key:
  deterministic_key:
  key_derivation_salt:

secret_key_base:

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
    iss: "tramline"
    aud: "applelink"
    secret: "any password"

  github:
    app_name:
    app_id:
    private_pem: |
```
Save the credentials file and commit your changes. Use this button **from your fork** to kick-off a Render deployment.

<p>
  <a href="https://render.com/deploy" target="_blank">
  <img src="https://render.com/images/deploy-to-render-button.svg" alt="Deploy to Render">
  </a>
</p>

The blueprint will ask for the `RAILS_MASTER_KEY`. Use the contents of `production.key` from the previous step.

### Setup applelink

If you would like to use the App Store integration, you'd have to configure the `applelink` service. You can skip this section otherwise.

1. To start off, in your fork, uncomment the `applelink` section from the `render.yaml` file.
2. Secondly, to your encryption file, add this to the integrations section, by running `bin/rails credentials:edit --environment production`. Choose a secret key for authorization.

```yaml
integrations:
  applelink:
    iss: "tramline.dev"
    aud: "applelink"
    secret: "any password"
```

3. Commit your changes and resync the blueprint on Render. This will kick-off the `applelink` service. This will most likely fail to deploy on the first attempt, because it requires certain environment configuration. To do that, create a `Secret File` under `applelink > Settings > Environment > Secret Files` called `.env` and update with the following details by putting the applelink secret from the previous step under `AUTH_SECRET`:

```
RACK_ENV=production
WEB_CONCURRENCY=2
MAX_THREADS=1
PORT=3001
AUTH_ISSUER="tramline"
AUTH_AUD="applelink"
AUTH_SECRET=""
SENTRY_DSN=""
```

### Wrap up

Before we wrap up, we need to fix a couple of ENV variables:

1. If you have setup applelink in the previous step, you must add an `APPLELINK_URL` to `site-web` with the final DNS of the `applelink` service.
2. The `HOSTNAME` in `site-web` and `site-jobs` must be updated to point to the DNS of `site-web` (without the protocol).

Once all services on Render are green, your setup should look like this:

<figure>
  <img alt="render.com services" src="art/render_dotcom_services.png" width="90%" />
</figure>

That should be it! You can use the default DNS from `site-web` to launch Tramline. You can configure and tweak more settings later.

## Local development 🛠️

### Setup

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

### Running

- Place the `master.key` file in the `config` directory.
- Start ngrok for [webhooks](#webhooks).
- Start PostgreSQL and Redis using [Homebrew services](https://github.com/Homebrew/homebrew-services).
- Finally, run `bin/dev`.

### Webhooks

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

### Adding or updating gems

* Use `bundle add <gem>` to add a new gem.
* To update a gem use `bundle update <gem>`.

Using the `bundle add` tool auto-applies
the [pessimistic operator](https://thoughtbot.com/blog/rubys-pessimistic-operator) in the `Gemfile`.
Although `Gemfile.lock` is the correct source of gem versions, specifying the pessimistic operator makes for a simpler
and safer update path through bundler for future users.

Doing this for development/test groups is optional.

### SSL

We use SSL locally and certificates are also generated as part of the setup script. It's recommended to
use https://tramline.local.gd:3000.

This is the default `HOST_NAME` that can be changed via `.env.development` if necessary.

### Letter Opener

All e-mails are caught and can be viewed [here](https://tramline.local.gd:3000/letter_opener).

### Sidekiq

The dashboard for all background jobs can be viewed [here](https://tramline.local.gd:3000/sidekiq).

### Flipper

All feature-flags are managed through flipper. The UI can be viewed [here](https://tramline.local.gd:3000/flipper).

## Contributing 👩🏻‍💻

We are still in the early stages and would <3 any feedback you have to offer. You can get in touch with us in several ways:

- Join our [Discord](https://discord.com/invite/u7VwyvBV2Z) server to ask us questions or share your thoughts
- Submit a [feature request or bug report](https://github.com/tramlinehq/tramline/issues/new/choose)
- Open a pull request (see instructions for local setup [here](#local-development-%EF%B8%8F))
