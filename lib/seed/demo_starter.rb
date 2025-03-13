# rubocop:disable Rails/Output

# TODO: using schema.rb, create a demo organization
# it should have 2 teams and 4 members in each team
# there should be 2 apps - one android and the other ios
# each app should have 10 - 15  historical releases
# 50 - 60 commits per release
# 1 release should be upcoming status and 1 should be running status, and the rest are completed (maybe a fraction of it could be stopped) - for each app
# integrations should be setup for each app - 1 version control, 1 build server (both can be github), 1 slack, 1 playstore (for the android app), 1 app store (for the ios app), 1 bugsnag

require "faker"

module Seed
  class DemoStarter
    def self.call
      new.call
    end

    def call
      puts "Cleaning existing data..."
      clean_data

      puts "Creating demo organization..."
      organization = create_organization

      puts "Creating admin user..."
      create_admin_user(organization)

      puts "Creating teams..."
      teams = create_teams(organization)

      puts "Creating team members..."
      create_team_members(teams, organization)

      puts "Creating apps (Android and iOS)..."
      apps = create_apps(organization)

      puts "Setting up trains for each app..."
      apps.each { |app| setup_train_for_app(app) }

      puts "Seed data creation completed!"
    end

    private

    def clean_data
      Organization.destroy_all
      User.destroy_all
      Team.destroy_all
      App.destroy_all
      Train.destroy_all
      Release.destroy_all
      Commit.destroy_all
      Integration.destroy_all
    end

    def create_organization
      Organization.create!(
        name: "Demo Organization",
        slug: "demo-org",
        status: "active",
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        api_key: SecureRandom.hex(16)
      )
    end

    def create_admin_user(organization)
      admin_user = User.create!(
        full_name: "Admin User",
        preferred_name: "Admin",
        email: "admin@example.com",
        encrypted_password: BCrypt::Password.create("password123"),
        slug: "admin-user",
        admin: true,
        confirmed_at: Time.zone.now,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Membership.create!(
        user: admin_user,
        organization: organization,
        role: "admin",
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      admin_user
    end

    def create_teams(organization)
      team_colors = %w[blue green]
      Array.new(2) do |i|
        Team.create!(
          organization: organization,
          name: "Team #{i + 1}",
          color: team_colors[i],
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )
      end
    end

    def create_team_members(teams, organization)
      teams.each do |team|
        4.times do |i|
          user = User.create!(
            full_name: Faker::Name.name,
            preferred_name: Faker::Name.first_name,
            email: Faker::Internet.email,
            encrypted_password: BCrypt::Password.create("password123"),
            slug: "user-#{team.id}-#{i}",
            confirmed_at: Time.zone.now,
            created_at: 1.year.ago,
            updated_at: 1.year.ago
          )

          Membership.create!(
            user: user,
            organization: organization,
            team: team,
            role: "developer",
            created_at: 1.year.ago,
            updated_at: 1.year.ago
          )
        end
      end
    end

    def random_date(from, to)
      from ||= Time.zone.at(0)
      to ||= Time.zone.now
      raise ArgumentError, "Invalid range for random_date" if from > to

      Time.zone.at(rand(from.to_i..to.to_i))
    end

    def create_apps(organization)
      platforms = %w[android ios]
      platforms.map do |platform|
        app = App.create!(
          organization: organization,
          name: "Demo #{platform.capitalize} App",
          description: "A demo #{platform} application",
          platform: platform,
          bundle_identifier: "com.demo.#{platform}app",
          build_number: 1,
          timezone: "UTC",
          slug: "demo-#{platform}-app",
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        # Create app config
        AppConfig.create!(
          app: app,
          code_repository: {type: "github", repository: "demo-org/#{platform}-app"},
          notification_channel: {type: "slack", channel: "##{platform}-releases"},
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        app
      end
    end

    def setup_train_for_app(app)
      train = Train.create!(
        app: app,
        name: "Main Train",
        description: "Main release train for #{app.name}",
        status: "active",
        branching_strategy: "gitflow",
        release_branch: "release",
        working_branch: "develop",
        slug: "main-train-#{app.id}",
        version_seeded_with: "1.0.0",
        version_current: "1.0.0",
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        kickoff_at: 1.year.ago,
        repeat_duration: 2.weeks,
        build_queue_enabled: true,
        tag_releases: true
      )

      release_platform = create_release_platform(app, train)
      build_step = create_release_platform_steps(release_platform)
      setup_integrations_for_app(app)

      setup_releases_and_commits(app, build_step, release_platform, train)
    end

    def create_release_platform(app, train)
      ReleasePlatform.create!(
        app: app,
        train: train,
        name: "#{app.platform.capitalize} Platform",
        description: "Release platform for #{app.platform}",
        status: "active",
        working_branch: "develop",
        branching_strategy: "gitflow",
        release_branch: "release",
        platform: app.platform,
        slug: "#{app.platform}-platform-#{app.id}",
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )
    end

    def create_release_platform_steps(release_platform)
      build_step = Step.create!(
        release_platform: release_platform,
        name: "Build",
        description: "Build the app",
        status: "active",
        step_number: 1,
        slug: "build-#{release_platform.id}",
        kind: "build",
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        ci_cd_channel: {type: "github_actions", workflow: "build.yml"}
      )

      platform_config = ReleasePlatform.create!(
        release_platform: release_platform,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      ReleaseStep.create!(
        release_platform_config: platform_config,
        kind: "store",
        auto_promote: false,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      build_step
    end

    def setup_integrations_for_app(app)
      puts "Creating integrations for #{app.name}..."

      # GitHub integration for version control
      github_integration = GithubIntegration.create!(
        installation_id: Faker::Number.number(digits: 8).to_s,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        app: app,
        category: "version_control",
        status: "active",
        providable: github_integration,
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        metadata: {repository: "demo-org/#{app.platform}-app"}
      )

      # GitHub integration for CI/CD
      build_integration = GithubIntegration.create!(
        installation_id: Faker::Number.number(digits: 8).to_s,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        app: app,
        category: "ci_cd",
        status: "active",
        providable: build_integration,
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        metadata: {repository: "demo-org/#{app.platform}-app", workflow: "build.yml"}
      )

      # Slack integration
      slack_integration = SlackIntegration.create!(
        oauth_access_token: "xoxb-#{Faker::Number.number(digits: 12)}-#{Faker::Number.number(digits: 12)}",
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        app: app,
        category: "notification",
        status: "active",
        providable: slack_integration,
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        metadata: {channel: "##{app.platform}-releases"}
      )

      # Store integration based on platform
      store_integration = if app.platform == "android"
        GooglePlayStoreIntegration.create!(
          json_key: "{ \"type\": \"service_account\", \"project_id\": \"demo-android-app-#{Faker::Number.number(digits: 6)}\" }",
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )
      else # iOS
        AppStoreIntegration.create!(
          key_id: "A#{Faker::Number.hexadecimal(digits: 10)}",
          issuer_id: Faker::Number.hexadecimal(digits: 8).to_s,
          p8_key: "-----BEGIN PRIVATE KEY-----\nMIIE#{Faker::Lorem.characters(number: 1000)}\n-----END PRIVATE KEY-----",
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )
      end

      Integration.create!(
        app: app,
        category: "app_store",
        status: "active",
        providable: store_integration,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Bugsnag integration
      bugsnag_integration = BugsnagIntegration.create!(
        access_token: Faker::Crypto.md5,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        app: app,
        category: "error_tracking",
        status: "active",
        providable: bugsnag_integration,
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        metadata: {project_id: Faker::Number.number(digits: 10).to_s}
      )
    end

    def setup_releases_and_commits(app, build_step, release_platform, train)
      num_releases = rand(12..15)
      release_statuses = ["completed"] * (num_releases - 2) + %w[upcoming running]

      num_stopped = (num_releases * 0.2).to_i
      release_statuses[0...num_stopped] = ["stopped"] * num_stopped

      release_statuses.shuffle!
      current_version = "1.0.0"

      if num_releases.is_a?(Integer)
        num_releases.times do |i|
          create_commit_for_release(app, build_step, current_version, i, release_platform, release_statuses, train)
        end
      end
    end

    def create_commit_for_release(app, build_step, current_version, i, release_platform, release_statuses, train)
      # Bump version for each release
      version_parts = current_version.split(".")
      if i % 3 == 0 && i > 0
        version_parts[1] = (version_parts[1].to_i + 1).to_s
        version_parts[2] = "0"
      else
        version_parts[2] = (version_parts[2].to_i + 1).to_s
      end
      current_version = version_parts.join(".")

      # Calculate dates for this release
      release_start_date = (i + 1).months.ago
      release_end_date = release_start_date + 2.weeks

      # Current date info for upcoming/running releases
      if release_statuses[i] == "upcoming"
        scheduled_at = 1.week.from_now
        completed_at = nil
        stopped_at = nil
      elsif release_statuses[i] == "running"
        scheduled_at = 2.days.ago
        completed_at = nil
        stopped_at = nil
      elsif release_statuses[i] == "stopped"
        scheduled_at = release_start_date
        completed_at = nil
        stopped_at = release_start_date + 2.days
      else
        # completed
        scheduled_at = release_start_date
        completed_at = release_end_date
        stopped_at = nil
      end

      release = Release.create!(
        train: train,
        branch_name: "release/#{current_version}",
        status: release_statuses[i],
        original_release_version: current_version,
        release_version: current_version,
        scheduled_at: scheduled_at,
        completed_at: completed_at,
        stopped_at: stopped_at,
        created_at: release_start_date,
        updated_at: [release_end_date, Time.zone.now].min,
        is_automatic: [true, false].sample,
        tag_name: "v#{current_version}",
        release_type: "standard",
        slug: "release-#{current_version.tr(".", "-")}"
      )

      release_platform_run = ReleasePlatformRun.create!(
        release_platform: release_platform,
        release: release,
        code_name: "R#{i + 1}",
        scheduled_at: scheduled_at,
        commit_sha: Faker::Crypto.sha1,
        status: release_statuses[i],
        branch_name: "release/#{current_version}",
        release_version: current_version,
        completed_at: completed_at,
        stopped_at: stopped_at,
        tag_name: "v#{current_version}",
        created_at: release_start_date,
        updated_at: [release_end_date, Time.zone.now].min
      )

      # Create release metadata with notes
      ReleaseMetadata.create!(
        release: release,
        release_platform_run: release_platform_run,
        locale: "en-US",
        release_notes: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
        default_locale: true,
        created_at: release_start_date,
        updated_at: release_start_date
      )

      # Create step runs
      step_run = CreateTrainStepRuns.create!(
        step: build_step,
        release_platform_run: release_platform_run,
        scheduled_at: release_start_date,
        status: if release_statuses[i] == "completed"
                  "completed"
                else
                  (release_statuses[i] == "running") ? "running" : "pending"
                end,
        created_at: release_start_date,
        updated_at: [release_end_date, Time.zone.now].min,
        build_version: current_version,
        build_number: (i + 100).to_s
      )

      # Create 50-60 commits per release
      num_commits = rand(50..60)

      if release_statuses[i] == "completed" || release_statuses[i] == "running"
        # Create a build if the release is completed or running
        build = Build.create!(
          release_platform_run: release_platform_run,
          version_name: current_version,
          build_number: (i + 100).to_s,
          generated_at: release_start_date + 1.day,
          created_at: release_start_date + 1.day,
          updated_at: release_start_date + 1.day,
          sequence_number: i + 1
        )

        # Create a build artifact
        BuildArtifact.create!(
          step_run: step_run,
          build: build,
          generated_at: release_start_date + 1.day,
          uploaded_at: release_start_date + 1.day,
          created_at: release_start_date + 1.day,
          updated_at: release_start_date + 1.day
        )

        # For completed releases, add a store submission
        if release_statuses[i] == "completed"
          StoreSubmission.create!(
            release_platform_run: release_platform_run,
            build: build,
            status: "approved",
            name: "Store Submission #{current_version}",
            type: "standard",
            prepared_at: release_start_date + 2.days,
            submitted_at: release_start_date + 2.days,
            approved_at: release_end_date - 1.day,
            store_status: "live",
            created_at: release_start_date + 2.days,
            updated_at: release_end_date
          )
        end
      end

      # Create commits
      commit_start_date = release_start_date - 1.week
      commit_end_date = release_start_date

      if num_commits.is_a?(Integer)
        num_commits.times do |j|
          commit_date = random_date(commit_start_date, commit_end_date)

          author = User.all.sample

          commit = Commit.create!(
            commit_hash: Faker::Crypto.sha1,
            release_platform: release_platform,
            release: release,
            release_platform_run: release_platform_run,
            message: "#{Faker::Hacker.verb} #{Faker::Hacker.noun} #{Faker::Hacker.ingverb} #{Faker::Hacker.adjective} #{Faker::Hacker.noun}",
            timestamp: commit_date,
            author_name: author.full_name,
            author_email: author.email,
            author_login: author.slug,
            url: "https://github.com/demo-org/#{app.platform}-app/commit/#{Faker::Crypto.sha1}",
            created_at: commit_date,
            updated_at: commit_date
          )

          # Add some pull requests
          if j % 10 == 0
            PullRequest.create!(
              release_platform_run: release_platform_run,
              release: release,
              commit: commit,
              number: j + 1,
              source_id: (j + 100).to_s,
              url: "https://github.com/demo-org/#{app.platform}-app/pull/#{j + 1}",
              title: "Feature: #{Faker::Hacker.say_something_smart}",
              body: Faker::Lorem.paragraphs(number: 2).join("\n\n"),
              state: "merged",
              phase: "development",
              source: "github",
              head_ref: "feature/#{Faker::Hacker.noun.parameterize}",
              base_ref: "develop",
              opened_at: commit_date - 1.day,
              closed_at: commit_date,
              created_at: commit_date - 1.day,
              updated_at: commit_date
            )
          end
        end
      end
    end
  end
end

# rubocop:enable Rails/Output
