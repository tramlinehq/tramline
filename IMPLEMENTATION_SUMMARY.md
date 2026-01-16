# Cross-Platform Release Independent Completion Implementation

## Overview

This implementation adds a new `concluded` state to `ReleasePlatformRun` to enable independent platform completion in cross-platform releases. This allows:

1. **Patch fixes on rolled-out platforms** - Commits can still be applied to platforms that have completed their rollout while the overall release is still active
2. **Per-platform upcoming release unblocking** - Upcoming releases can start production rollouts for platforms whose corresponding run in the ongoing release has rolled out

## New State: `concluded`

### State Machine

```
created → on_track → concluded → finished
            ↑ ________|
          ↘ stopped
```

### State Semantics

- **`on_track`**: Active development, accepting commits, building, submitting
- **`concluded`**: Production rollout complete, but release still active
  - ✅ Can accept patch fix commits (for critical issues)
  - ✅ Unblocks upcoming release for this platform
  - ✅ Automatically transitions back to `on_track` when a new commit lands
  - ❌ Automatically transitions to `finished` when upcoming release starts production
- **`finished`**: Release is finalized, completely done, no more work

## Files Changed

### Models

1. **`app/models/release_platform_run.rb`**
   - Added `concluded` to `STATES` enum
   - Updated `pending_release` scope to exclude `concluded`
   - Added `conclude!` method to transition from `on_track` → `concluded`
   - Updated `start!` to allow transition from `concluded` → `on_track` (reactivation)
   - Updated `finish!` to transition from `concluded` → `finished`
   - Kept `active?` as only `created` and `on_track` (workflow states)
   - Added `committable?` to check if commits can be applied (created, on_track, or concluded)
   - Added `reactivated` to `STAMPABLE_REASONS`

2. **`app/models/release.rb`**
   - Updated `ready_to_be_finalized?` to include `concluded` state
   - Updated `blocked_for_production_release?` to accept `for_platform_run` parameter
   - Added per-platform unblocking logic for upcoming releases

3. **`app/models/production_release.rb`**
   - Updated `actionable?` to pass `for_platform_run` parameter

### Coordinators

4. **`app/libs/coordinators/finish_platform_run.rb`**
   - Changed `release_platform_run.finish!` → `release_platform_run.conclude!`
   - Updated event stamp reason from `:finished` → `:concluded`

5. **`app/libs/coordinators/finalize_platform_run.rb`** (NEW)
   - Created new coordinator to transition `concluded` → `finished`

6. **`app/libs/coordinators/start_production_release.rb`**
   - Added `finalize_previous_release_platform_run!` method
   - Automatically finalizes corresponding platform run in ongoing release when upcoming release starts production

7. **`app/libs/coordinators/apply_commit.rb`**
   - Changed `next unless run.on_track?` → `next unless run.committable?`
   - Now applies commits to platforms where `committable?` returns true (created, on_track, or concluded)
   - Added `reactivate_if_concluded` method to transition `concluded` → `on_track` when new commit lands
   - Emits `reactivated` event stamp when platform is reactivated

8. **`app/libs/coordinators/finalize_release.rb`**
   - Added finalization of all `concluded` platform runs when release finishes

### UI Components

9. **`app/components/platform_view_component.html.erb`**
   - Added conditional rendering for `concluded` state
   - Shows success message: "rollout is complete, but critical fixes can still be applied"

### Database

10. **`db/migrate/20260116000000_backfill_concluded_state_for_release_platform_runs.rb`**
    - Backfills existing `finished` platform runs in `partially_finished` releases to `concluded`

## Flow Example

### Scenario: Android Finishes First, iOS Still in Review

```
T0: Current Release starts
├─ Android: created → on_track
├─ iOS: created → on_track

T1: Android production rollout completes
├─ Android: on_track → concluded ✅
├─ iOS: on_track
├─ Release: on_track → partially_finished
├─ New commits: Apply to BOTH Android and iOS ✅
├─ Android: concluded → on_track (reactivated) ✅

T2: Upcoming release starts production for Android
├─ Current Release Android: concluded → finished ✅
├─ Current Release iOS: on_track
├─ Upcoming Release Android: starts production ✅
├─ New commits: Apply ONLY to Current iOS ✅

T3: Current iOS finishes
├─ Current Release Android: finished
├─ Current Release iOS: on_track → concluded
├─ Release: partially_finished → post_release_started → finished
├─ Current Release iOS: concluded → finished
├─ Upcoming Release iOS: can now start ✅
```

## Semantic Separation: active? vs committable?

To prevent semantic confusion, we maintain two separate query methods:

- **`active?`**: Returns true for `created` and `on_track` states only
  - Used for workflow state checks (can start internal/beta/production releases?)
  - Used by coordinators to determine if platform run is in active development
  - Used by UI to show platform status

- **`committable?`**: Returns true for `created`, `on_track`, and `concluded`
  - Used specifically for commit application logic
  - Allows patch fixes to be applied even after platform rollout completes
  - When a commit lands on a `concluded` platform, it automatically transitions back to `on_track`

This separation ensures that `concluded` platforms can accept commits but won't inadvertently trigger new internal/beta releases.

**Note:** Supersession is handled automatically through state transitions. When an upcoming release starts production for a platform, the corresponding `concluded` platform run in the ongoing release is transitioned to `finished` by `StartProductionRelease`, making it no longer `committable?`.

## Key Constraints Enforced

1. **Only one active rollout per platform at a time** - When upcoming release starts production, the corresponding platform run in ongoing release is automatically finalized (`concluded` → `finished`)
2. **No commits to superseded platforms** - Enforced through state transitions (only `created`, `on_track`, and `concluded` are committable; superseded platforms are `finished`)
3. **Atomic state transitions** - All state changes use `with_lock` for consistency

## Testing Recommendations

1. **Cross-platform release with staggered completion**
   - Start iOS + Android release
   - Finish iOS → verify it transitions to `concluded`
   - Land new commit → verify applies to both platforms
   - Verify upcoming release iOS can start production

2. **Patch fix on rolled-out platform**
   - Platform A rolls out
   - Platform B still in progress
   - Land critical fix commit
   - Verify new build created for Platform A
   - Verify can submit new production release for Platform A

3. **Upcoming release supersedes rolled-out platform**
   - Platform A rolls out in current release
   - Start production for Platform A in upcoming release
   - Verify current Platform A transitions to `finished`
   - Verify commits no longer apply to current Platform A

4. **Release finalization**
   - All platforms reach `concluded` state
   - Finalize release
   - Verify all platforms transition to `finished`

## Migration Notes

- Existing releases in `partially_finished` state will have their `finished` platform runs backfilled to `concluded`
- No schema changes required (string enum values)
- Backwards compatible - old states still work
