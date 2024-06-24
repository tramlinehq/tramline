# This module is a collection of high-level events for a release
#
#                    ┌────────────────────────┐
#                  ┌─│  Release Platform Run  │──┐
#                  │ └────────────────────────┘  │
#                  │              │              │
#                  ▼              │              ▼
#     ┏━━━━━━━━━━━━━━━━━━━━━━━━┓  │ ┏━━━━━━━━━━━━━━━━━━━━━━━━┓
#     ┃   Pre-Prod Releases    ┃  │ ┃                        ┃
#  ┌──┃                        ┃▒ │ ┃  Production Releases   ┃──┐
#  │  ┃   (Internal / Beta)    ┃▒ │ ┃                        ┃▒ │
#  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━┛▒ │ ┗━━━━━━━━━━━━━━━━━━━━━━━━┛▒ │
#  │   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │
#  │   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ │
#  │             ┌──────────────┐ │  ┌──────────────┐           │
#  │             │ Workflow Run │ │  │    Build     │◀──────────┤
#  │ ┌───────────┼──────────────┤ │  └──────────────┘           │
#  │ │   Build   │              │ │  ┌────────────────────────┐ │
#  │ │ Metadata  │    Build     │ │  │ Release Health Metrics │ │
#  │ └───────────┴──────────────┘ │  └────────────────────────┘ │
#  │                     │        │               ▲             │
#  │                     │        │               │             │
#  │                     ▼        │               └─────────────┤
#  │             ┌──────────────┐ │  ┌──────────────┐           │
#  │             │ Submissions  │ │  │ Submissions  │           │
#  │             ├──────────────┤ │  ├──────────────┤           │
#  │             │   Rollout    │ │  │   Rollout    │◀──────────┘
#  │             └──────────────┘ ▼  └──────────────┘
#  │                 ┌────────────────────────┐
#  └────────────────▶│   Regression Testing   │
#                    └────────────────────────┘
#
# == It ought to be used in the following way ==
# • At the boundaries of user input or external events (controllers, api listeners)
# • To listen to signals from terminal states in a live release
#
# == Note ==
# • All subsequent dispatch work is kicked off from this point.
# • This does not replace internal state machines of other sub-models.
# • It currently does not have any state of its own.
module Coordinators::Signals
  def self.start_release!(release)
    return unless release_platform_run.organization.product_v2?
    # PreRelease.call(release)
    # NewRelease.call(release)
  end

  def self.new_commit_landed!(release)
    return unless release_platform_run.organization.product_v2?
    WebhookProcessors::PushJob.perform_later(release.id, head_commit, rest_commits)
    # check if patchfix/hotfix etc
    # check if we need to trigger rc
    # StartPrepareForRelease.call(release)
  end

  def self.build_available_for_regression_testing!(build)
    return unless release_platform_run.organization.product_v2?
    # StartRegressionTesting.call(build)
  end

  def self.regression_testing_approved!(build)
    return unless release_platform_run.organization.product_v2?
    # StartBetaRelease.call(build)
  end

  def self.beta_release_available!(build)
    return unless release_platform_run.organization.product_v2?
    # start soak, or
    # StartProductionRelease.call(build)
  end

  def self.production_release_complete!(submission)
    return unless release_platform_run.organization.product_v2?
    # WrapUpRelease.call(build)
  end

  def self.release_complete!(release)
    return unless release_platform_run.organization.product_v2?
    # WrapUpRelease.call(build)
  end
end

# Coordinators::Signals.start_release!(release)
# Coordinators::Signals.new_commit_landed!(release)
# Coordinators::Signals.build_available_for_regression_testing!(build)
# Coordinators::Signals.regression_testing_approved!(build)
# Coordinators::Signals.beta_release_available!(build)
# Coordinators::Signals.production_release_complete!(submission)
# Coordinators::Signals.release_complete!(release)

