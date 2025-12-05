# Tramline Developer Guide for AI Assistants

This document provides comprehensive guidance for AI assistants working on the Tramline codebase. Tramline is a sophisticated mobile release management platform built with Ruby on Rails that orchestrates the entire release lifecycle for iOS and Android applications.

## Table of Contents

1. [Quick Start](#quick-start)
2. [Codebase Overview](#codebase-overview)
3. [Core Architecture Patterns](#core-architecture-patterns)
4. [Domain Model](#domain-model)
5. [Development Workflows](#development-workflows)
6. [Testing Guidelines](#testing-guidelines)
7. [Common Patterns and Gotchas](#common-patterns-and-gotchas)
8. [Rails Best Practices](#rails-best-practices)
9. [Stimulus Controllers](#stimulus-controllers)

---

## Quick Start

### Essential Commands

Tramline uses Docker for development with commands wrapped in a Justfile:

```bash
just --list                      # See all available commands
just start                       # Start development environment
just rails <command>             # Run Rails commands in container
just spec <file>                 # Run specific spec file
just pspec                       # Run all specs in parallel
just lint                        # Check code quality and formatting
just rails db:migrate:with_data  # Run schema + data migrations
just shell <service>             # Open shell in container (default: web)
just attach <service>            # Attach to running container for pry
```

### Local Development

- Main URL: https://tramline.local.gd:3000
- Sidekiq dashboard: https://tramline.local.gd:3000/sidekiq
- Letter Opener (emails): https://tramline.local.gd:3000/letter_opener
- Flipper (feature flags): https://tramline.local.gd:3000/flipper

---

## Codebase Overview

### Technology Stack

**Backend:**
- Ruby 3.3.6 / Rails 7.1
- PostgreSQL 14 (with pgcrypto, pg_trgm extensions)
- Redis for caching and job queues
- Sidekiq for background jobs

**Frontend:**
- Hotwire (Turbo Rails + Stimulus)
- Tailwind CSS 2.0
- ViewComponent 3.0 for reusable UI
- Importmap for JavaScript

**Key Libraries:**
- **State Machines**: AASM 5.3
- **Versioning**: Paper Trail 15.1
- **Feature Flags**: Flipper 1.3
- **Authentication**: Devise 4.9 + Descope (SSO)
- **Monitoring**: Sentry, Datadog
- **File Storage**: Google Cloud Storage

### Directory Structure

```
app/
├── assets/          # Static assets (stylesheets, images)
├── channels/        # ActionCable websocket channels
├── components/      # ViewComponent-based UI components
├── controllers/     # Rails controllers (organized by domain)
├── helpers/         # View helpers
├── javascript/      # Stimulus JS controllers
├── jobs/            # Sidekiq background jobs
├── libs/            # Service objects and business logic ⭐
│   ├── coordinators/   # Orchestrate complex workflows
│   ├── installations/  # External API clients
│   ├── queries/        # Complex query objects
│   ├── notifiers/      # Notification delivery
│   ├── triggers/       # Event triggering system
│   └── validators/     # Custom validation logic
├── mailers/         # Email templates and mailers
├── models/          # ActiveRecord models
│   ├── accounts/       # User, Organization, Team
│   ├── config/         # Configuration objects
│   ├── concerns/       # Shared model behaviors
│   └── ...             # Domain models
├── presenters/      # Presentation layer objects
├── refinements/     # Ruby refinements
├── types/           # Type definitions
└── views/           # ERB templates

config/              # Configuration files
db/                  # Database migrations and schema
lib/                 # Extended libraries and utilities
spec/                # RSpec test suite
  ├── factories/        # FactoryBot factories
  ├── fixtures/         # Test fixtures (API responses)
  ├── support/          # Shared examples and helpers
  └── ...               # Organized like app/
```

---

## Core Architecture Patterns

### 1. Coordinators Pattern (`app/libs/coordinators/`)

**Purpose**: High-level orchestrators for complex multi-step workflows at system boundaries.

**Key Characteristics:**
- Stateless - no persistence of their own state
- Use class method `.call()` pattern
- Return `GitHub::Result` monad for error handling
- Delegate domain logic to models
- Use `Memery` gem for memoization

**Example Structure:**
```ruby
class Coordinators::StartRelease
  include Memery

  def self.call(train, **release_params)
    new(train, **release_params).call
  end

  def initialize(train, **release_params)
    @train = train
    @release_params = release_params
  end

  def call
    return GitHub::Result.new { validation_error } unless valid?

    release = Release.create!(@release_params)
    release.start!
    release.event_stamp!(reason: :release_started, kind: :success)

    # Kick off async jobs
    Coordinators::PreReleaseJob.perform_async(release.id)

    GitHub::Result.new { release }
  end

  private

  def valid?
    # Validation logic
  end

  memoize def validation_error
    # Error construction
  end
end
```

**Two Main Modules:**
- `Coordinators::Signals` - Event-based triggers from terminal states (automatic)
- `Coordinators::Actions` - User/external input boundary actions (manual)

**When to Create a Coordinator:**
- Multi-step workflows across models
- Orchestration at system boundaries (user actions, webhooks)
- Complex state transitions requiring multiple operations
- Workflows involving external API calls

**Examples in Codebase:**
- `Coordinators::StartRelease` - Start a new release
- `Coordinators::FinalizeRelease` - Complete and tag release
- `Coordinators::CreateBetaRelease` - Create internal distribution
- `Coordinators::PreRelease::*` - Strategy pattern by branching strategy
- `Coordinators::Webhooks::*` - Process external webhooks
- `Coordinators::SoakPeriod::*` - Nested coordinators for feature-specific logic

**Model Bloat Prevention:**
Models should contain ONLY:
- Query methods (return data/state without side effects)
- Delegation to related objects
- Validations and associations
- State machine definitions

Models should NOT contain:
- Bang methods that modify state (`start!`, `complete!`, etc. go in coordinators)
- Complex business logic (use coordinators)
- Multi-step workflows (use coordinators)

```ruby
# BAD - Bang methods in model
class Release < ApplicationRecord
  def end_soak_period!(user)
    return false unless user_is_pilot?(user)
    with_lock do
      update!(soak_started_at: calculated_time)
      event_stamp!(reason: :soak_ended)
    end
  end
end

# GOOD - Query methods in model, actions in coordinators
class Release < ApplicationRecord
  # Query methods only
  def soak_period_active?
    soak_started_at.present? && !soak_period_completed?
  end

  def soak_end_time
    return nil if soak_started_at.blank?
    soak_started_at + soak_period_hours.hours
  end
end

# Business logic in coordinator
class Coordinators::SoakPeriod::End
  def initialize(release, user)
    @release = release
    @user = user
  end

  def call
    return false unless authorized?
    return false unless @release.soak_period_active?

    @release.with_lock do
      @release.update!(soak_started_at: calculated_time)
      @release.event_stamp!(reason: :soak_period_ended_early)
    end
    true
  end
end

# Exposed via Actions module
module Coordinators::Actions
  def self.end_soak_period!(release, user)
    result = SoakPeriod::End.new(release, user).call
    return Res.ok(release) if result
    Res.err(error_message)
  end
end
```

**Race Condition Prevention:**
Always use `with_lock` in coordinators for concurrent operations:
```ruby
def call
  @release.with_lock do
    # Double-check conditions inside lock
    return false if @release.soak_started_at.present?

    @release.update!(soak_started_at: Time.current)
    @release.event_stamp!(reason: :soak_started)
  end
end
```

### 2. Passport System (Event Tracking & Audit Trail)

**Purpose**: Polymorphic audit trail for all important events in the system.

**Core Components:**
- `Passport` model - The stamp record
- `Passportable` concern - Mixin for stampable models
- `PassportJob` - Async job for creating stamps

**Usage Pattern:**
```ruby
# In any Passportable model
release.event_stamp!(
  reason: :release_started,        # Symbol matching STAMPABLE_REASONS
  kind: :success,                  # :success, :error, :notice
  data: {version: "1.2.0"},        # Optional additional data
  author: current_user             # Optional (auto-detected from Current.user)
)
```

**Model Setup:**
```ruby
class Release < ApplicationRecord
  include Passportable

  # Define allowed stamp reasons
  STAMPABLE_REASONS = [
    :release_started,
    :release_completed,
    :release_failed,
    :build_attached,
    # ...
  ].freeze

  # Namespace for I18n messages
  def stamp_namespace
    "release"
  end
end
```

**I18n Messages:**
Place messages in `config/locales/passport.en.yml`:
```yaml
en:
  passport:
    release:
      release_started_html: "Release <strong>%{release_version}</strong> started"
      release_completed_html: "Release completed successfully"
```

**When to Create Stamps:**
- Important state transitions
- User actions (approvals, manual triggers)
- External events (webhook processing)
- Error conditions
- Anything visible in timeline/audit trail

### 3. State Machine Pattern (AASM)

**Used In**: Core domain models (Release, StoreSubmission, ReleasePlatformRun, Build)

**Pattern:**
```ruby
class Release < ApplicationRecord
  include AASM

  # Define states as hash with string values (important!)
  STATES = {
    created: "created",
    pre_release_started: "pre_release_started",
    on_track: "on_track",
    post_release_started: "post_release_started",
    finished: "finished",
    stopped: "stopped"
  }.freeze

  # State groups for queries
  TERMINAL_STATES = %w[finished stopped stopped_after_partial_finish].freeze
  ACTIVE_STATES = %w[created pre_release_started on_track post_release_started].freeze

  # Use enum alongside AASM for query scopes
  enum :status, STATES

  aasm safe_state_machine_params(with_lock: false) do
    state :created, initial: true
    state :pre_release_started
    state :on_track
    state :post_release_started
    state :finished

    event :start do
      transitions from: [:created, :pre_release_started], to: :on_track

      # Create audit trail after transition
      after do
        event_stamp!(reason: :release_started, kind: :success)
      end
    end

    event :finish do
      transitions from: :post_release_started, to: :finished

      after do
        self.completed_at = Time.current
        event_stamp!(reason: :release_completed, kind: :success)
      end
    end
  end

  # Scopes from enum
  scope :active, -> { where(status: ACTIVE_STATES) }
  scope :terminal, -> { where(status: TERMINAL_STATES) }
end
```

**Key Conventions:**
- Always define `STATES` constant as hash with string values
- Use Rails `enum` alongside AASM for query scopes
- Create state group constants (`TERMINAL_STATES`, `FAILED_STATES`)
- Use `after` blocks for stamps and side effects
- Use `with_lock` option for concurrent updates

**State Machine Models:**
- `Release` - Main release lifecycle (7 states)
- `ReleasePlatformRun` - Platform-specific run (6 states)
- `StoreSubmission` - App store submission (10+ states)
- `StoreRollout` - Phased rollout control
- `WorkflowRun` - CI/CD workflow execution
- `Build` - Build artifact lifecycle

### 4. Polymorphic Integration Pattern

**Core Model**: `Integration` with double polymorphism using `delegated_type`

**Pattern:**
```ruby
class Integration < ApplicationRecord
  # Provider types (the external service)
  PROVIDER_TYPES = %w[
    GithubIntegration GitlabIntegration BitbucketIntegration
    SlackIntegration AppStoreIntegration GooglePlayStoreIntegration
    BitriseIntegration GoogleFirebaseIntegration BugsnagIntegration
    CrashlyticsIntegration JiraIntegration LinearIntegration
  ].freeze

  # What it integrates with (App or AppVariant)
  INTEGRABLE_TYPES = %w[App AppVariant].freeze

  # Double polymorphism
  delegated_type :providable, types: PROVIDER_TYPES, autosave: true
  delegated_type :integrable, types: INTEGRABLE_TYPES, autosave: true

  # Integration categories
  enum :category, {
    version_control: "version_control",
    ci_cd: "ci_cd",
    notification: "notification",
    build_channel: "build_channel",
    monitoring: "monitoring",
    project_management: "project_management"
  }

  # Platform-aware integration checking
  def self.allowed_for?(app, category, provider_type)
    allowed_providers = ALLOWED_INTEGRATIONS_FOR_APP.dig(
      app.platform.to_sym,
      category
    )
    allowed_providers&.include?(provider_type)
  end
end
```

**Provider Implementation:**
```ruby
class GithubIntegration < ApplicationRecord
  include Integrable

  has_one :integration, as: :providable, touch: true

  # Common interface methods
  def installation_path
    # Return OAuth installation URL
  end

  def connection_data
    # Return data for connection display
  end

  def public_icon_img
    # Return icon path
  end

  def project_link(repo_id)
    "https://github.com/#{repo_namespace(repo_id)}"
  end

  # Provider-specific methods
  def create_pr!(branch, target_branch, title, body)
    # GitHub API implementation
  end

  def fetch_commits(repo_id, branch)
    # GitHub API implementation
  end
end
```

**Usage:**
```ruby
# Get typed provider
integration.providable  # Returns GithubIntegration instance

# Check provider type
integration.providable_type == "GithubIntegration"
integration.github_integration?  # Convenience method

# Use provider methods
integration.providable.create_pr!(...)
```

### 5. Query Objects Pattern (`app/libs/queries/`)

**Purpose**: Encapsulate complex database queries with business logic.

**Pattern:**
```ruby
class Queries::Releases
  include Memery

  def self.all(**params)
    new(**params).all
  end

  def initialize(app:, params: {})
    @app = app
    @params = params
    @limit = params[:limit] || DEFAULT_LIMIT
    @offset = params[:offset] || 0
  end

  def all
    records.limit(@limit).offset(@offset).map do |record|
      # Transform to presentation object or SimpleDelegator
      ReleasePresenter.new(record)
    end
  end

  private

  memoize def records
    @app.releases
      .includes(:train, :release_platform_runs, :builds)
      .where(status: Release::ACTIVE_STATES)
      .order(scheduled_at: :desc)
  end
end
```

**When to Use:**
- Complex queries with multiple joins/CTEs
- Queries combining business logic
- Queries used in multiple places
- Queries returning computed/aggregated data
- Analytics and reporting queries

**Examples:**
- `Queries::DevopsReport` - Release analytics
- `Queries::PlatformBreakdown` - Platform-specific metrics
- `Queries::Releases` - Filtered release lists
- `Queries::Builds` - Build search and filtering

### 6. ViewComponent Pattern (`app/components/`)

**Purpose**: Encapsulate UI logic and authorization in reusable, testable components.

**Key Principles:**
- Components fully encapsulate their logic (no logic in views)
- Pass `current_user` when authorization is needed
- Methods return safe defaults (never nil for display methods)
- Use private methods for internal logic
- Test components like Ruby classes (not integration tests)

**Pattern:**
```ruby
# app/components/live_release/soak_component.rb
class LiveRelease::SoakComponent < ViewComponent::Base
  def initialize(release, current_user)
    @release = release
    @current_user = current_user
  end

  # Public methods for view
  def show_soak_actions?
    @release.soak_period_active? && user_is_release_pilot?
  end

  def show_pilot_only_message?
    @release.soak_period_active? && !user_is_release_pilot?
  end

  # Display methods with nil safety
  def time_remaining_display
    soak_seconds = (@release.soak_time_remaining || 0).to_i
    hours = soak_seconds / 3600
    minutes = (soak_seconds % 3600) / 60
    seconds = soak_seconds % 60
    sprintf("%02d:%02d:%02d", hours, minutes, seconds)
  end

  def soak_start_time_display
    return nil unless @release.soak_started_at.present?
    @release.soak_started_at.in_time_zone(app_timezone).strftime("%Y-%m-%d %H:%M %Z")
  end

  private

  def user_is_release_pilot?
    return false if @current_user.blank?
    @current_user.id == @release.release_pilot_id
  end

  def app_timezone
    @release.train.app.timezone
  end
end
```

**View Template:**
```erb
<!-- app/components/live_release/soak_component.html.erb -->
<div class="soak-period">
  <% if @release.soak_period_active? %>
    <div class="timer">
      <span data-controller="countdown" data-countdown-seconds-value="<%= time_remaining_hours * 3600 %>">
        <%= time_remaining_display %>
      </span>
    </div>

    <% if show_soak_actions? %>
      <%= button_to "End Early", end_soak_release_beta_soak_path(@release), method: :post %>
      <%= button_to "Extend", extend_soak_release_beta_soak_path(@release), method: :post %>
    <% elsif show_pilot_only_message? %>
      <p class="text-gray-500">Only release pilot can modify soak period</p>
    <% end %>
  <% end %>
</div>
```

**Usage in Controller/View:**
```ruby
# In controller
def soak
  @release = Release.find(params[:id])
  render
end
```

```erb
<!-- In view -->
<%= render LiveRelease::SoakComponent.new(@release, current_user) %>
```

**Testing Components:**
```ruby
RSpec.describe LiveRelease::SoakComponent, type: :component do
  let(:release) { create(:release, :with_soak) }
  let(:pilot) { release.release_pilot }
  let(:other_user) { create(:user) }
  let(:component) { described_class.new(release, pilot) }

  describe "#show_soak_actions?" do
    it "returns true when user is pilot and soak is active" do
      expect(component.show_soak_actions?).to eq(true)
    end

    it "returns false when user is not pilot" do
      component = described_class.new(release, other_user)
      expect(component.show_soak_actions?).to eq(false)
    end
  end

  describe "#time_remaining_display" do
    it "returns formatted time without wrapping at 24 hours" do
      release.update!(soak_started_at: 1.hour.ago, soak_period_hours: 48)
      expect(component.time_remaining_display).to match(/^47:\d{2}:\d{2}$/)
    end

    it "returns 00:00:00 for nil values" do
      allow(release).to receive(:soak_time_remaining).and_return(nil)
      expect(component.time_remaining_display).to eq("00:00:00")
    end
  end
end
```

**Key Conventions:**
- Component class file: `app/components/namespace/name_component.rb`
- Component view file: `app/components/namespace/name_component.html.erb`
- Component JS controller: `app/components/namespace/name_component_controller.js` (if needed)
- Always encapsulate authorization logic in component
- Never return nil from display methods (use safe defaults)
- Test all authorization paths and nil cases

### 7. Computations Pattern (`app/libs/computations/`)

**Purpose**: Calculate complex derived state and step statuses for releases.

**Main Use Case**: `Computations::Release::StepStatuses` - Determines visibility and state of each release step.

**Status Types:**
```ruby
STATUS = {
  blocked: :blocked,      # Step cannot proceed (dependency not met)
  unblocked: :unblocked,  # Step is available but not started
  ongoing: :ongoing,      # Step is in progress
  success: :success,      # Step completed successfully
  none: :none,           # Step has no data yet
  hidden: :hidden        # Step not visible for this configuration
}
```

**Pattern:**
```ruby
class Computations::Release::StepStatuses
  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    {
      statuses: {
        changeset_tracking: changeset_tracking_status,
        release_candidate: release_candidate_status,
        soak_period: soak_period_status,
        app_submission: app_submission_status,
        rollout_to_users: rollout_to_users_status
      }.compact,
      current_overall_status: current_overall_status
    }
  end

  def soak_period_status
    # Hidden if feature not enabled
    return STATUS[:hidden] unless @release.soak_period_enabled?

    # Blocked if RC not ready
    return STATUS[:blocked] if release_candidate_status != STATUS[:success]

    # Success if completed
    return STATUS[:success] if @release.soak_period_completed?

    # Ongoing if active
    return STATUS[:ongoing] if @release.soak_period_active?

    # Otherwise blocked (not started)
    STATUS[:blocked]
  end

  def app_submission_status
    # Soak period blocks submission
    return STATUS[:blocked] if @release.soak_period_enabled? && !@release.soak_period_completed?

    # Other blocking conditions
    return STATUS[:blocked] if @release.approvals_blocking?
    return STATUS[:blocked] if all_platforms? { |rp| rp.production_releases.none? }

    return STATUS[:ongoing] if any_platforms? { |rp| rp.inflight_production_release.present? }

    STATUS[:success]
  end
end
```

**Key Concepts:**
- Steps can be `hidden` based on configuration (e.g., soak period disabled)
- Steps can `block` other steps (e.g., soak blocks app submission)
- Status determination flows from dependencies (RC → Soak → Submission)
- Pure computation - no side effects, only reading state

**Usage:**
```ruby
statuses = Computations::Release::StepStatuses.call(release)

# Check specific step status
if statuses[:statuses][:soak_period] == :ongoing
  # Show countdown timer
end

# Use for UI styling
step_class = case statuses[:statuses][:app_submission]
  when :blocked then "text-gray-400"
  when :ongoing then "text-blue-500"
  when :success then "text-green-500"
end
```

**Testing Computations:**
```ruby
RSpec.describe Computations::Release::StepStatuses do
  let(:release) { create(:release, :with_soak) }

  describe "#soak_period_status" do
    it "returns hidden when soak disabled" do
      release.train.update!(soak_period_enabled: false)
      result = described_class.call(release)
      expect(result[:statuses][:soak_period]).to eq(:hidden)
    end

    it "returns blocked when RC not ready" do
      result = described_class.call(release)
      expect(result[:statuses][:soak_period]).to eq(:blocked)
    end

    it "returns ongoing when soak active" do
      setup_rc_ready(release)
      release.update!(soak_started_at: 1.hour.ago)
      result = described_class.call(release)
      expect(result[:statuses][:soak_period]).to eq(:ongoing)
    end
  end
end
```

---

## Domain Model

### Core Hierarchy

```
Organization (multi-tenant root)
  └── App (mobile application: android/ios/cross_platform)
       ├── Integrations (external services)
       │    ├── GithubIntegration (version control)
       │    ├── SlackIntegration (notifications)
       │    ├── AppStoreIntegration (distribution)
       │    └── BitriseIntegration (CI/CD)
       └── Trains (release pipeline configurations)
            ├── ReleasePlatforms (iOS/Android specific config)
            └── Releases (specific release instances)
                 ├── ReleasePlatformRuns (platform-specific runs)
                 │    ├── WorkflowRuns (CI/CD executions)
                 │    ├── Builds (binary artifacts)
                 │    ├── PreProdReleases (internal/beta)
                 │    │    └── StoreSubmissions
                 │    └── ProductionReleases
                 │         ├── StoreSubmissions
                 │         └── StoreRollouts (staged rollouts)
                 ├── Commits (code changes in release)
                 ├── PullRequests (related PRs)
                 └── ApprovalItems (release approvals)
```

### Key Domain Concepts

**Train**: Release pipeline configuration
- Branching strategy (almost_trunk, release_backmerge, parallel_working)
- Versioning strategy (semver variants)
- Workflow configurations
- Submission settings

**Release**: Specific release instance
- Has branch name and version number
- Type: `release` (normal) or `hotfix` (emergency)
- Lifecycle: created → pre_release → on_track → post_release → finished
- Creates ReleasePlatformRuns for each active platform

**ReleasePlatformRun**: Platform-specific (iOS or Android) execution
- Manages builds, submissions, rollouts for one platform
- Cross-platform apps have 2 runs per release

**Build**: Binary artifact from CI/CD
- Kind: `internal` or `release_candidate`
- Has build number, artifact (file), metadata
- Connected to workflow run and commit

**StoreSubmission**: Submission to app store
- Platform-specific: `TestFlightSubmission`, `PlayStoreSubmission`
- Complex state machine (preprocessing → prepared → submitted → approved → finished)

**StoreRollout**: Phased/staged rollout to production
- Platform-specific stages (App Store: 1%, 2%, 5%, 10%, 20%, 50%, 100%)
- Can be paused, resumed, fully released

### Multi-Tenancy

**Organization Scoping:**
- Use `Current.organization` set by controllers/middleware
- All queries should scope by organization to prevent leaks
- Chain: Organization → App → Train → Release → ReleasePlatformRun

**Current Attributes** (`app/models/current.rb`):
```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :organization, :user, :app_id
end
```

### Cross-Platform Handling

**App Platforms:**
```ruby
enum :platform, {
  android: "android",
  ios: "ios",
  cross_platform: "cross_platform"
}
```

**Important Patterns:**
- Release creates ReleasePlatformRuns for each active platform
- Cross-platform apps must have both iOS and Android integrations
- Platform-specific classes: `AppStoreSubmission` vs `PlayStoreSubmission`
- Platform ordering: Android (1), iOS (2), Cross-platform (3)
- Hotfixes can target specific platform via `hotfix_platform`

---

## Development Workflows

### Adding a New Feature

1. **Understand the domain** - Read related models, coordinators, tests
2. **Check existing patterns** - Look for similar features
3. **Plan data model changes** - Migrations follow Rails conventions
4. **Implement in layers**:
   - Models (business logic, validations, state machines)
   - Coordinators (orchestration)
   - Jobs (async processing)
   - Controllers (user input boundary)
   - Views/Components (UI)
5. **Add stamps** - Event tracking for visibility
6. **Write tests** - Factories, specs following existing patterns
7. **Update docs** - If adding new patterns/conventions

### Creating a New Integration

1. **Create provider model**: `app/models/{service}_integration.rb`
2. **Include `Integrable` concern**
3. **Add to `Integration::PROVIDER_TYPES`**
4. **Implement common interface**: `installation_path`, `connection_data`, `public_icon_img`
5. **Add provider-specific methods**
6. **Create API client**: `app/libs/installations/{service}/api.rb`
7. **Add to allowed integrations**: `Integration::ALLOWED_INTEGRATIONS_FOR_APP`
8. **Create credentials section**: `config/credentials.yml.enc`
9. **Add factory**: `spec/factories/{service}_integrations.rb`
10. **Create fixtures**: `spec/fixtures/{service}/` for API responses

### Adding a New Background Job

```ruby
class MyFeatureJob < ApplicationJob
  sidekiq_options retry: 0, queue: :default

  # For retryable jobs with external APIs
  sidekiq_options retry: 25
  sidekiq_retry_in do |count, ex, msg|
    if retryable_failure?(ex)
      backoff_in(attempt: count + 1, period: :minutes, type: :exponential)
    else
      :kill
    end
  end

  # Handle exhausted retries
  sidekiq_retries_exhausted do |msg, ex|
    release = Release.find(msg["args"].first)
    release.event_stamp!(reason: :my_feature_failed, kind: :error)
  end

  def perform(release_id, params)
    release = Release.find(release_id)

    # Do work
    result = external_api_call(release, params)

    # Create stamp on success
    release.event_stamp!(reason: :my_feature_completed, kind: :success)
  end

  private

  def retryable_failure?(ex)
    ex.is_a?(HTTP::TimeoutError) || ex.is_a?(Net::ReadTimeout)
  end
end
```

**Queue Priorities:**
- `:high` - Critical path, coordinators (weight: 3)
- `:default` - Most jobs (weight: 1)
- `:low` - Background cleanup (weight: 1)

### Working with State Machines

**Making State Transitions:**
```ruby
# Always use with_lock for concurrent safety
release.with_lock do
  return unless release.may_start?  # Check guard
  release.start!                    # Transition
  # Additional operations
end
```

**Adding New States:**
1. Add to `STATES` constant
2. Update `enum :status`
3. Add to state groups if needed
4. Define transitions in AASM block
5. Add stamps in `after` blocks
6. Update queries/scopes
7. Add specs for new transitions

### Debugging

**Useful Tools:**
- `just attach` - Attach to running container for pry
- `just devlog` - Tail development log
- `just bglog` - Tail Sidekiq log
- Sidekiq dashboard: https://tramline.local.gd:3000/sidekiq
- Flipper UI: https://tramline.local.gd:3000/flipper

**Common Debug Points:**
- Passport stamps - Check event trail
- Sidekiq retries - Check Sidekiq dashboard for errors
- State machine guards - Check `may_#{event}?` methods
- Current attributes - Verify `Current.organization` is set
- Integration calls - Check `spec/fixtures/` for expected responses

---

## Testing Guidelines

### RSpec Configuration

- Location: `spec/`
- Factory definitions: `spec/factories/`
- Fixtures (API responses): `spec/fixtures/`
- Shared examples: `spec/*/shared_examples/`
- Support files: `spec/support/`

### Factory Patterns

**Use Traits for Variations:**
```ruby
FactoryBot.define do
  factory :release do
    train
    scheduled_at { Time.current }
    status { "on_track" }
    branch_name { "release-v1.0" }
    release_type { "release" }

    # State variations
    trait :created do
      status { "created" }
    end

    trait :finished do
      status { "finished" }
      completed_at { Time.current }
    end

    # Type variations
    trait :hotfix do
      release_type { "hotfix" }
    end

    # Skip callbacks for faster tests
    trait :with_no_platform_runs do
      after(:build) do |release|
        def release.create_platform_runs!
          true  # No-op
        end
      end
    end
  end
end
```

**Usage:**
```ruby
let(:release) { create(:release, :finished, train: train) }
let(:hotfix) { create(:release, :hotfix, :created) }
let(:fast_release) { create(:release, :with_no_platform_runs) }
```

### Mocking External APIs

**Pattern 1: Instance Doubles**
```ruby
let(:github_api) { instance_double(GithubIntegration) }

before do
  allow(app).to receive(:vcs_provider).and_return(github_api)
  allow(github_api).to receive(:create_pr!).and_return(
    GitHub::Result.new { {number: 123, url: "..."} }
  )
end
```

**Pattern 2: WebMock Stubs**
```ruby
def stub_github_api
  stub_request(:post, "https://api.github.com/repos/owner/repo/pulls")
    .with(body: hash_including(title: "Release PR"))
    .to_return(
      status: 201,
      body: file_fixture("github/pull_request.json").read,
      headers: {"Content-Type" => "application/json"}
    )
end
```

**Pattern 3: Test Helpers** (`spec/support/helpers.rb`)
```ruby
module TestHelpers
  def parse_github_fixture(filename)
    JSON.parse(file_fixture("github/#{filename}").read)
  end
end

RSpec.configure do |config|
  config.include TestHelpers
end
```

### Testing Coordinators

```ruby
RSpec.describe Coordinators::StartRelease do
  let(:train) { create(:train, :active) }
  let(:params) { {scheduled_at: Time.current} }

  describe ".call" do
    subject(:result) { described_class.call(train, **params) }

    context "when valid" do
      it "creates a release" do
        expect { result }.to change(Release, :count).by(1)
      end

      it "returns success result" do
        expect(result).to be_ok
        expect(result.value).to be_a(Release)
      end

      it "creates event stamp" do
        expect { result }.to change(Passport, :count).by(1)
      end

      it "enqueues pre-release job" do
        expect { result }.to have_enqueued_sidekiq_job(
          Coordinators::PreReleaseJob
        )
      end
    end

    context "when invalid" do
      let(:params) { {scheduled_at: nil} }

      it "returns error result" do
        expect(result).not_to be_ok
        expect(result.error).to include("scheduled_at")
      end
    end
  end
end
```

### Testing Jobs

```ruby
RSpec.describe MyFeatureJob do
  let(:release) { create(:release, :on_track) }

  describe "#perform" do
    subject(:perform) { described_class.new.perform(release.id) }

    before do
      stub_external_api
    end

    it "processes successfully" do
      expect { perform }.not_to raise_error
    end

    it "creates success stamp" do
      expect { perform }.to change { release.stamps.count }.by(1)
      expect(release.stamps.last.reason).to eq("my_feature_completed")
    end

    context "when API fails" do
      before do
        stub_external_api_failure
      end

      it "raises for retry" do
        expect { perform }.to raise_error(HTTP::TimeoutError)
      end
    end
  end
end
```

### Test Organization

Follow app structure:
```
spec/
├── controllers/
├── jobs/
├── libs/
│   ├── coordinators/
│   └── queries/
├── models/
├── requests/
└── components/
```

### Testing Best Practices

**Test Authorization at All Levels:**
```ruby
RSpec.describe Coordinators::SoakPeriod::End do
  let(:release) { create(:release, :with_active_soak) }
  let(:pilot) { release.release_pilot }
  let(:other_user) { create(:user, :as_developer) }

  context "authorization" do
    it "succeeds when user is release pilot" do
      result = described_class.new(release, pilot).call
      expect(result).to be_truthy
    end

    it "fails when user is not release pilot" do
      result = described_class.new(release, other_user).call
      expect(result).to be_falsey
    end

    it "fails when user is nil" do
      result = described_class.new(release, nil).call
      expect(result).to be_falsey
    end
  end
end
```

**Test Nil Safety:**
```ruby
describe "#time_remaining_display" do
  it "returns safe default when time_remaining is nil" do
    allow(release).to receive(:time_remaining).and_return(nil)
    expect(component.time_remaining_display).to eq("00:00:00")  # Not nil
  end

  it "handles nil timestamps" do
    release.update!(soak_started_at: nil)
    expect(component.soak_start_time_display).to be_nil  # Explicit nil is OK
  end
end
```

**Test Edge Cases and Boundaries:**
```ruby
describe "validations" do
  it "validates minimum boundary (1 hour)" do
    train = build(:train, soak_period_enabled: true, soak_period_hours: 1)
    expect(train).to be_valid
  end

  it "validates maximum boundary (168 hours)" do
    train = build(:train, soak_period_enabled: true, soak_period_hours: 168)
    expect(train).to be_valid
  end

  it "rejects below minimum (0 hours)" do
    train = build(:train, soak_period_enabled: true, soak_period_hours: 0)
    expect(train).not_to be_valid
  end

  it "rejects above maximum (169 hours)" do
    train = build(:train, soak_period_enabled: true, soak_period_hours: 169)
    expect(train).not_to be_valid
  end

  it "rejects negative values" do
    train = build(:train, soak_period_enabled: true, soak_period_hours: -5)
    expect(train).not_to be_valid
  end
end
```

**Test State Transitions:**
```ruby
describe "soak period status transitions" do
  it "transitions from blocked to ongoing when soak starts" do
    statuses_before = Computations::Release::StepStatuses.call(release)
    expect(statuses_before[:statuses][:soak_period]).to eq(:blocked)

    release.update!(soak_started_at: 1.hour.ago)

    statuses_after = Computations::Release::StepStatuses.call(release)
    expect(statuses_after[:statuses][:soak_period]).to eq(:ongoing)
  end

  it "transitions from ongoing to success when soak completes" do
    release.update!(soak_started_at: 1.hour.ago)
    expect(release.soak_period_active?).to eq(true)

    travel 24.hours do
      expect(release.soak_period_active?).to eq(false)
      expect(release.soak_period_completed?).to eq(true)
    end
  end
end
```

**Test Time Calculations:**
```ruby
describe "#soak_end_time" do
  it "calculates correctly with default hours (24)" do
    start_time = Time.current
    release.update!(soak_started_at: start_time)
    expected_end = start_time + 24.hours
    expect(release.soak_end_time).to be_within(1.second).of(expected_end)
  end

  it "calculates correctly with custom hours" do
    start_time = Time.current
    release.train.update!(soak_period_hours: 48)
    release.update!(soak_started_at: start_time)
    expected_end = start_time + 48.hours
    expect(release.soak_end_time).to be_within(1.second).of(expected_end)
  end

  it "returns 0 when time has passed" do
    release.update!(soak_started_at: 25.hours.ago)
    expect(release.soak_time_remaining).to eq(0)
  end
end
```

---

## Common Patterns and Gotchas

### Result Monad Pattern

Many coordinators return `GitHub::Result` for error handling:

```ruby
result = Coordinators::StartRelease.call(train, params)

# Pattern 1: Check result
if result.ok?
  release = result.value
  # Success path
else
  errors = result.error
  # Error path
end

# Pattern 2: Use callbacks
result
  .on_success { |release| redirect_to release_path(release) }
  .on_error { |error| render :new, alert: error }
```

### Locking Pattern

**Always use locks for state transitions:**
```ruby
release.with_lock do
  return unless release.committable?
  release.start!
  release.create_platform_runs!
end
```

### Memery for Memoization

Use `Memery` instead of `||=`:
```ruby
include Memery

memoize def expensive_computation
  # Only computed once, even if returns nil/false
end

# Instead of:
def expensive_computation
  @expensive_computation ||= ...  # Breaks if returns false!
end
```

### Enum with String Values

**Always use string pairs:**
```ruby
# CORRECT
enum status: {
  shipped: "shipped",
  being_packed: "being_packed",
  complete: "complete"
}

# WRONG - Don't use integer enums
enum status: [:shipped, :being_packed, :complete]
```

This allows:
- Better readability in SQL
- Safer schema evolution
- Symbol and string queries both work

### Version Comparison

Use `.to_semverish` extension:
```ruby
"1.2.0".to_semverish >= "1.1.0".to_semverish  # => true
"1.10.0".to_semverish > "1.9.0".to_semverish  # => true
```

### Time Handling

**Use Time.current (not Time.now):**
```ruby
# CORRECT - Rails timezone-aware
release.update!(started_at: Time.current)
deadline = Time.current + 24.hours

# WRONG - Not timezone-aware
release.update!(started_at: Time.now)  # Don't use!
```

**Display Times in App Timezone:**
```ruby
# Store times in UTC, display in app's configured timezone
def formatted_deadline
  return nil unless deadline.present?
  deadline.in_time_zone(app.timezone).strftime("%Y-%m-%d %H:%M %Z")
end

# Example output: "2025-01-15 14:30 EST"
```

**Duration Display (Don't Use Time.at for Long Durations):**
```ruby
# BAD - Wraps at 24 hours!
def time_remaining_display
  seconds = 100_000  # 27.7 hours
  Time.at(seconds).utc.strftime("%H:%M:%S")  # Returns "03:46:40" (wrong!)
end

# GOOD - Manual calculation for durations
def time_remaining_display
  seconds = (@release.time_remaining || 0).to_i
  hours = seconds / 3600
  minutes = (seconds % 3600) / 60
  secs = seconds % 60
  sprintf("%02d:%02d:%02d", hours, minutes, secs)  # Returns "27:46:40" (correct!)
end
```

**Conditional Validations with Time:**
```ruby
class Train < ApplicationRecord
  # Validate only when feature is enabled
  validates :soak_period_hours,
    presence: true,
    numericality: {greater_than: 0, less_than_or_equal_to: 168},
    if: -> { soak_period_enabled? }
end
```

**Time Calculations:**
```ruby
# Adding duration
end_time = start_time + 24.hours
end_time = start_time + hours.hours  # Dynamic hours

# Time remaining (with safe minimum)
time_left = [end_time - Time.current, 0].max

# Checking if time has passed
completed? = Time.current >= end_time
```

**Nil Safety:**
Always provide safe defaults for display methods:
```ruby
def time_remaining_hours
  seconds = @release.time_remaining || 0  # Default to 0
  seconds / 3600.0
end

def formatted_time
  return nil unless timestamp.present?  # Return nil if no data
  timestamp.in_time_zone(timezone).strftime(format)
end
```

### Common Pitfalls

**1. Forgetting Event Stamps**
Always create stamps for important events:
```ruby
release.start!
release.event_stamp!(reason: :release_started, kind: :success)  # Don't forget!
```

**2. Not Using Coordinators**
Don't put complex orchestration in models/controllers:
```ruby
# BAD
def create
  release = Release.create!(params)
  release.start!
  release.create_platform_runs!
  PreReleaseJob.perform_async(release.id)
end

# GOOD
def create
  result = Coordinators::Actions.start_release!(train, params)
  result.on_success { |release| redirect_to release }
end
```

**3. Missing Platform Checks**
Always check platform when needed:
```ruby
# BAD
submission.provider.upload_build!(build)

# GOOD
if app.ios?
  submission.provider.upload_to_testflight!(build)
elsif app.android?
  submission.provider.upload_to_play_store!(build)
end
```

**4. Assuming Job Order**
Jobs are async - don't assume order:
```ruby
# BAD
Job1.perform_async(id)
Job2.perform_async(id)  # Might run first!

# GOOD - Use Signals pattern
Job1.perform_async(id)
# Job1 calls Signal.job1_completed(id)
# Signal enqueues Job2
```

**5. Stale Records in Jobs**
Always reload in jobs:
```ruby
def perform(release_id)
  release = Release.find(release_id)  # Fresh from DB
  # Not: use @release passed to job
end
```

### Integration Webhook Patterns

**Webhook Coordinator:**
```ruby
class Coordinators::Webhooks::Push < Coordinators::Webhooks::Base
  def process
    return Response.new(:accepted) unless valid?

    # Queue async processing
    Webhooks::PushJob.perform_async(release.id, head_commit.to_h)
    Response.new(:accepted)
  end

  private

  memoize def runner
    # Provider-specific parser
    return GITHUB::Push.new(payload) if github?
    return GITLAB::Push.new(payload) if gitlab?
    BITBUCKET::Push.new(payload) if bitbucket?
  end

  def valid?
    runner.branch_name == release.branch_name &&
      runner.repository_name == release.repository_name
  end
end
```

**Pattern:**
1. Validate quickly in webhook controller
2. Queue async job for processing
3. Return 200 OK immediately
4. Use provider-specific parsers for payload

---

## Rails Best Practices

### ActiveRecord Queries

```ruby
# Range queries
Book.where(created_at: (Time.current.midnight - 1.day)..Time.current.midnight)

# IN queries
Customer.where(orders_count: [1, 3, 5])
Customer.where.not(orders_count: [1, 3, 5])

# OR queries
Customer.where(last_name: "Smith").or(Customer.where(orders_count: [1, 3, 5]))

# Ordering
Book.order(title: :asc, created_at: :desc)

# Limit/Offset
Customer.limit(5).offset(30)

# Group by with counts
Order.group(:status).count

# Having clause
Order.select("created_at as date, sum(total) as price")
  .group("created_at")
  .having("sum(total) > ?", 200)

# Annotate for debugging
User.annotate("selecting active users").where(active: true)

# Efficient iteration
Customer.where(active: true).find_each do |customer|
  # Process one at a time
end
```

### Scopes

```ruby
class Product < ApplicationRecord
  scope :in_print, -> { where(out_of_print: false) }
  scope :expensive, -> { where("price > ?", 500) }
  scope :recent, -> { where("created_at > ?", 1.week.ago) }

  # Chainable
  # Product.in_print.expensive.recent
end
```

### Callbacks

```ruby
class Order < ApplicationRecord
  # Available callbacks
  before_validation
  after_validation
  before_save
  before_create
  after_create
  after_commit
  before_destroy
  after_initialize
  after_find

  # Conditional callbacks
  before_save :normalize_card_number, if: :paid_with_card?
  after_create :send_email, unless: :admin?

  # With lambda
  before_save :encrypt_ssn, if: ->(order) { order.ssn.present? }

  # Halt with throw :abort
  before_save :check_valid_state

  def check_valid_state
    throw :abort if invalid_state?
  end
end
```

### Strong Parameters (Rails 7.1+)

```ruby
def product_params
  params.expect(product: [:name, :description, :price])
end

# Nested
def release_params
  params.expect(release: [
    :scheduled_at,
    :branch_name,
    config: [:auto_promote, :rollout_enabled]
  ])
end
```

### Associations

```ruby
class Author < ApplicationRecord
  has_many :books, dependent: :destroy
  has_one :profile, dependent: :destroy
end

class Book < ApplicationRecord
  belongs_to :author
  has_many :chapters, dependent: :destroy
  has_many :reviews, dependent: :nullify
end

# Through associations
class Physician < ApplicationRecord
  has_many :appointments
  has_many :patients, through: :appointments
end

# Polymorphic
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end
```

### Views and Partials

```ruby
# Render partial with locals
<%= render "form", product: @product %>
<%= render partial: "product", locals: {product: @product} %>

# Shorthand (Rails convention)
<%= render @product %>  # Renders products/_product.html.erb

# Collection
<%= render partial: "product", collection: @products %>

# With spacer
<%= render partial: @products, spacer_template: "product_ruler" %>

# Caching
<% cache @product do %>
  <h1><%= @product.name %></h1>
<% end %>
```

### I18n

```ruby
# In view
<h1><%= t ".title" %></h1>

# In config/locales/en.yml
en:
  products:
    index:
      title: "All Products"

# Switch locale
around_action :switch_locale

def switch_locale(&action)
  locale = params[:locale] || I18n.default_locale
  I18n.with_locale(locale, &action)
end
```

### Concerns

```ruby
# app/models/concerns/taggable.rb
module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :tags, as: :taggable, dependent: :destroy
    scope :tagged_with, ->(tag) { joins(:tags).where(tags: {name: tag}) }
  end

  def tag_names
    tags.pluck(:name)
  end
end

# In model
class Article < ApplicationRecord
  include Taggable
end
```

### Importmaps (JavaScript)

```ruby
# config/importmap.rb
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# In view
<%= javascript_importmap_tags %>
```

---

## Stimulus Controllers

### Key Principles

1. **Use declarative actions, not imperative event listeners**
2. **Keep controllers lightweight** (< 7 targets)
3. **Single responsibility** per controller
4. **Component controllers** stay in their component

### Declarative Pattern

**BAD - Imperative:**
```javascript
// Don't do this!
export default class extends Controller {
  static targets = ["button", "content"]

  connect() {
    this.buttonTarget.addEventListener("click", this.toggle.bind(this))
  }

  toggle() {
    this.contentTarget.classList.toggle("hidden")
  }
}
```

**GOOD - Declarative:**
```erb
<!-- Declare in HTML -->
<div data-controller="toggle">
  <button data-action="click->toggle#toggle" data-toggle-target="button">
    Show
  </button>
  <div data-toggle-target="content" class="hidden">
    Hello World!
  </div>
</div>
```

```javascript
// Controller just responds
export default class extends Controller {
  static targets = ["button", "content"]

  toggle() {
    this.contentTarget.classList.toggle("hidden")
    this.buttonTarget.textContent =
      this.contentTarget.classList.contains("hidden") ? "Show" : "Hide"
  }
}
```

### Controller Structure

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output", "input"]
  static values = { url: String, refreshInterval: Number }
  static classes = ["loading", "error"]

  connect() {
    // Called when controller connects to DOM
    this.startPolling()
  }

  disconnect() {
    // Called when controller disconnects from DOM
    this.stopPolling()
  }

  // Action methods (called from HTML)
  submit(event) {
    event.preventDefault()
    this.performSubmit()
  }

  // Private methods
  performSubmit() {
    // Implementation
  }

  // Lifecycle callbacks
  urlValueChanged() {
    // Called when url value changes
  }
}
```

### Best Practices

**Keep it Simple:**
```javascript
// GOOD - Simple, focused controller
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  hide() {
    this.menuTarget.classList.add("hidden")
  }
}
```

**Use Values:**
```javascript
export default class extends Controller {
  static values = { url: String, pollInterval: { type: Number, default: 5000 } }

  connect() {
    this.poll()
  }

  poll() {
    fetch(this.urlValue)
      .then(response => response.text())
      .then(html => this.element.innerHTML = html)

    this.timeout = setTimeout(() => this.poll(), this.pollIntervalValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

**Use Classes:**
```erb
<div data-controller="loader"
     data-loader-loading-class="opacity-50"
     data-loader-error-class="border-red-500">
  <!-- content -->
</div>
```

```javascript
export default class extends Controller {
  static classes = ["loading", "error"]

  load() {
    this.element.classList.add(this.loadingClass)
    // ... fetch data
    this.element.classList.remove(this.loadingClass)
  }
}
```

### Component Controllers

**Rule**: If a Stimulus controller is in `app/components/`, it should ONLY be used in that component's view, not in `app/views/`.

```
app/
├── components/
│   └── modal/
│       ├── component.html.erb
│       └── component_controller.js  # Only used in modal component
└── javascript/
    └── controllers/
        └── form_controller.js  # Can be used anywhere
```

### Domain Logic

**Don't put domain logic in Stimulus:**
```javascript
// BAD - Domain logic in controller
export default class extends Controller {
  calculateDiscount() {
    // Complex business logic
    const basePrice = parseFloat(this.priceTarget.value)
    const discount = this.isVip ? basePrice * 0.2 : basePrice * 0.1
    return basePrice - discount
  }
}

// GOOD - Fetch from server
export default class extends Controller {
  async calculateDiscount() {
    const response = await fetch(`/api/calculate_discount`, {
      method: "POST",
      body: JSON.stringify({price: this.priceTarget.value})
    })
    const data = await response.json()
    this.displayDiscount(data.discount)
  }
}
```

---

## Additional Resources

### Important Files

- `config/routes.rb` - Application routes
- `db/schema.rb` - Database schema
- `config/sidekiq.yml` - Background job configuration
- `Justfile` - Development commands
- `compose.yml` - Docker Compose configuration
- `.env.development.sample` - Environment variables template

### External Documentation

- [Tramline README](README.md) - Setup and deployment
- Rails Guides: https://guides.rubyonrails.org/
- Hotwire Docs: https://hotwired.dev/
- Stimulus Handbook: https://stimulus.hotwired.dev/handbook/introduction
- AASM: https://github.com/aasm/aasm
- Sidekiq: https://github.com/sidekiq/sidekiq/wiki

### Key Conventions Summary

**Architecture:**
1. **Always use string enums**: `enum status: {active: "active"}`
2. **Create stamps for events**: `event_stamp!(reason: :..., kind: :...)`
3. **Use coordinators for orchestration**: Not models/controllers
4. **Models have query methods only**: No bang methods or business logic
5. **Lock state transitions**: `with_lock { release.start! }`
6. **Use Result monad**: `result.on_success { }.on_error { }`
7. **Scope by organization**: Prevent multi-tenant leaks

**Components & Views:**
8. **Encapsulate all logic in components**: Including authorization
9. **Components return safe defaults**: Never nil for display methods
10. **Pass current_user to components**: When authorization is needed

**Time & Data:**
11. **Use Time.current (not Time.now)**: Rails timezone-aware
12. **Display in app timezone**: `in_time_zone(app.timezone)`
13. **Manual calculation for long durations**: Don't use Time.at for > 24 hours
14. **Conditional validations**: Use `if:` lambda for feature flags

**Testing:**
15. **Test authorization at all levels**: Coordinator, component, controller
16. **Test nil safety**: All display methods with nil inputs
17. **Test edge cases**: Boundaries, negatives, zero values
18. **Test state transitions**: Before/after state changes
19. **Test with factories**: Use traits for variations

**Frontend:**
20. **Platform-aware code**: Check `ios?` / `android?` / `cross_platform?`
21. **Reload in jobs**: Records may be stale
22. **Declarative Stimulus**: Actions in HTML, not addEventListener

---

This guide covers the essential patterns and conventions for working on Tramline. When in doubt, look for existing similar code and follow the same patterns.
