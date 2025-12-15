# Tramline Developer Guide for AI Assistants

This document provides comprehensive guidance for AI assistants working on the Tramline codebase. Tramline is a sophisticated mobile release management platform built with Ruby on Rails that orchestrates the entire release lifecycle for iOS and Android applications.

### Essential Commands

Read the `Justfile` for all the essential commands related to development.

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
