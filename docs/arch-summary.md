# Tramline Design and Architecture Summary

From an infrastructural PoV, Tramline has a very straightforward architecture. It's primarily a monolithic Ruby on Rails application, with a couple of small services augmenting it. The service is deployed currently on Render, and the frontend, the backend, the task queues, and integration proxies are all self-contained.

## Background

Even though, the authors are originally more favorable towards writing backends in Go or Clojure, Rails was chosen because of its full-stack capabilities (job queues, frontend etc.). Since Tramline by design is not particularly a high-throughput service on the consumer-front, Rails's supposed pitfalls are not of any serious concern. Tramline is extremely background-job and workflow-orchestration heavy, and the ecosystem that Rails provides for these use-cases works pretty well and is reasonably performant to use.

## Frontend

All the frontend is server-side rendered, and uses the [Hotwire](https://hotwired.dev) (from Basecamp fame) and [ViewComponent](https://viewcomponent.org) (from GitHub) stack. Dynamic behaviour is achieved by using a combination of [Turbo](https://turbo.hotwired.dev) and [StimulusJS](https://stimulus.hotwired.dev). The app is not an SPA, but some of its features "behave" like an SPA without necessitating a full-fledged framework like React (or its derivatives).

This system has worked well so far, because we're a very tiny team (2-person engineering team at the time of this draft).

## High-level

![](../art/overall-arch@1x.png)

### Applelink

[Applelink](https://github.com/tramlinehq/applelink) is a sidecar service that we built to handle our App Store Connect integration. This is special in a way, because all other integrations so far are a native part of the monolith, but this one has been extracted out. The service is designed in a way where it's entirely independent of Tramline and can be used statelessly from other projects.

The reason for extracting this was a purely technically one initially, we use Fastlane's internal APIs to interact with ASC (since Fastlane is a CLI), and this avoids the potential dependency conflicts with Fastlane's versioning needs with Ruby and its gems and also avoids polluting the Tramline app with a mammoth dependency.

This service also adds recipes as API endpoints that abstract **a ton of** things you have to do to perform a general task on ASC. See the [rationale here](https://github.com/tramlinehq/applelink#rationale) for more info.

> [!NOTE]
> We run a tiny project called [App Store Slackbot](https://appstoreslackbot.com) that is a wrapper over Applelink to execute some basic ASC-related commands from Slack directly; like current status or pausing the rollout.

### Task Queues

Tramline uses [Sidekiq](https://sidekiq.org) for all its task-queueing needs (using a persistent Redis instance) and a tiny job-orchestration system built on top of it, [Coordinators](https://github.com/tramlinehq/tramline/blob/main/app/libs/coordinators.rb).

### Data

We use PostgreSQL as our OLTP db, and Redis for caches or transient data, like acquiring distributed locks.

### Storage

We currently use [GCS](https://cloud.google.com/storage) for storing assets and more importantly all the build artifacts generated from CI/CD pipelines. The build artifacts have a forced expiry in the buckets, so we never keep them around for longer than necessary.

### Integrations

We always use the official APIs for all our integrations, and we constantly keep them updated (another benefit of having all the integrations in the monolith). We also never use any third-party libraries to connect to the official APIs, if the libraries are not official, we default to wrapping them ourselves. This ensures tha we have control over any breaking changes in the APIs, and we can resolve issues faster.

### Observability

We use Sentry for error reporting and APM. [Axiom](https://axiom.co) for log streaming, and [PgHero](https://github.com/ankane/pghero) for database monitoring.

### Store Sweeper

[Store Sweeper](https://github.com/tramlinehq/store-sweeper) is a new independent service that we've built to allow users to search for their app from Tramline directly to enhance the onboarding experience. It's a stateless Node.js service that combines and interleaves the results from both App Store and Play Store and returns an enriched paginated response of the result.

## Development

Tramline development is dockerized and some recipes wrapped over to retain the Rails-experience in a containerized env. Refer to the [README](https://github.com/tramlinehq/tramline#local-development-%EF%B8%8F) for more details.

## Deployment

Refer to the [README](https://github.com/tramlinehq/tramline#how-to-set-it-up-yourself-%EF%B8%8F) on how we manage deployments.
