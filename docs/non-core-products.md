# Non-core products

## Buildkansen

→ https://github.com/tramlinehq/buildkansen

Buildkansen is a service + infra offering of custom, pooled macOS runners for GitHub managed by Tramline. It's a Go service that optimistically pools native VMs on cloud-hosted mac-machines. This exists, because we feel like there's a lot of room and value in the pricing that GH offers for its mac runners and we can provide better performance and cost-control flexibility at superior prices.

BK is able to retain privacy and isolation by destroying VMs after work is done, but is able to optimize idle-time (and hence cost) by optimisitcally pooling VMs before new requests hit.

There are a handful of free users of this service. Since it's not (yet) a core product.

## AppStoreSlackBot

→ https://appstoreslackbot.com

This is for folks who just want to augment ASC from Slack and aren't yet willing to buy into Tramline wholesale. It's written in Go and wraps over Applelink.

There are also a handful of intermittent, free users of this service.

## Macige

→ https://macige.tramline.app

This service is not used much any longer, but in the early days of Tramline it was really helpful in onboarding people if they didn't have proper CI/CD workflows set up. The value of this service is not very high since LLMs can do most of this work for us now, but it's a neat little artifact written in Rust + WASM to peruse through.
