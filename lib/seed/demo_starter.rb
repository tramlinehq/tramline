# rubocop:disable Rails/Output

# TODO:
# using schema.rb, create a demo organization
# it should have 2 teams and 4 members in each team
# there should be 2 apps - one android and the other ios
# each app should have 10 - 15  historical releases
# 50 - 60 commits per release
# 1 release should be upcoming status and 1 should be running status, and the rest are completed (maybe a fraction of it could be stopped) - for each app
# integrations should be setup for each app - 1 version control, 1 build server (both can be github), 1 slack, 1 playstore (for the android app), 1 app store (for the ios app), 1 bugsnag

require "faker"

module Seed
  class DemoStarter
    include Seed::Constants

    def self.call
      new.call
    end

    def size_config
      case ENV.fetch("SEED_SIZE", "medium").downcase
      when "small"
        { teams: 1, members_per_team: 4, releases: 5..8, commits_per_release: 20..30 }
      when "medium"
        { teams: 2, members_per_team: 6, releases: 10..15, commits_per_release: 50..60 }
      when "large"
        { teams: 3, members_per_team: 8, releases: 20..25, commits_per_release: 80..100 }
      else
        raise ArgumentError, "Invalid SEED_SIZE. Valid values are: small, medium, large."
      end
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
      Commit.delete_all
      PullRequest.delete_all
      BuildArtifact.delete_all
      Build.delete_all
      ReleaseMetadata.delete_all
      ReleasePlatformRun.delete_all
      ReleasePlatform.delete_all
      Release.delete_all
      Steps.delete_all
      Integration.delete_all
      AppConfig.delete_all
      ReleaseIndexComponent.delete_all
      ReleaseIndex.delete_all
      Train.delete_all
      App.delete_all
      Accounts::Membership.delete_all
      Accounts::Team.delete_all
      Accounts::UserAuthentication.delete_all
      Accounts::User.delete_all
      Accounts::Organization.delete_all
    end

    def create_organization
      Accounts::Organization.create!(
        name: "Demo Organization",
        slug: "demo-org",
        status: "active",
        created_at: 1.year.ago,
        updated_at: 1.year.ago,
        created_by: "admin@example.com"
      )
    end

    def create_admin_user(organization)
      email_authentication = Accounts::EmailAuthentication.find_or_initialize_by(email: "admin@example.com")

      unless email_authentication.persisted?
        admin_user = Accounts::User.create!(
          full_name: "Admin User",
          preferred_name: "Admin",
          unique_authn_id: "admin@example.com",
          slug: "admin-user",
          admin: true,
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        email_authentication.update!(
          password: ADMIN_PASSWORD,
          confirmed_at: DateTime.now,
          user: admin_user
        )
        email_authentication.reload

        Accounts::Membership.create!(
          user: admin_user,
          organization: organization,
          role: Accounts::Membership.roles[:owner],
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        puts "Added/updated admin user."
      end

      admin_user
    end

    def create_teams(organization)
      team_colors = %w[blue green]
      Array.new(size_config[:teams]) do |i|
        Accounts::Team.create!(
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
        size_config[:teams].times do |i|
          ActiveRecord::Base.transaction do
            user = Accounts::User.create!(
              full_name: Faker::Name.name,
              preferred_name: Faker::Name.first_name,
              unique_authn_id: Faker::Internet.email,
              slug: "user-#{team.id}-#{i}",
              created_at: 1.year.ago,
              updated_at: 1.year.ago
            )

            # Create email authentication for the user
            Accounts::EmailAuthentication.create!(
              email: user.unique_authn_id,
              password: DEVELOPER_PASSWORD,
              confirmed_at: Time.zone.now,
              user: user,
              created_at: 1.year.ago,
              updated_at: 1.year.ago
            )

            Accounts::Membership.create!(
              user: user,
              organization: organization,
              team: team,
              role: Accounts::Membership.roles[:developer],
              created_at: 1.year.ago,
              updated_at: 1.year.ago
            )
          end
        end
      end

      puts "Created team members."
    end

    def random_date(from, to)
      from ||= Time.zone.at(0)
      to ||= Time.zone.now

      if from > to
        raise ArgumentError, "Invalid range for random_date"
      end

      Time.zone.at(rand(from.to_i..to.to_i))
    end

    def create_apps(organization)
      %w[android ios].map do |platform|
        app = App.find_or_create_by!(
          organization: organization,
          name: "Demo #{platform.capitalize} App",
          description: "A demo #{platform} application",
          platform: platform,
          bundle_identifier: "com.demo.#{platform}_app",
          build_number: Faker::Number.number(digits: 5),
          timezone: "UTC",
          slug: "demo-#{platform}-app",
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        # Check if AppConfig exists for this app
        app_config = AppConfig.find_by(app: app)

        unless app_config
          AppConfig.create!(
            app: app,
            code_repository: {type: "github", repository: "demo-org/#{platform}-app"}.to_json,
            created_at: 1.year.ago,
            updated_at: 1.year.ago
          )
        end

        # Set up the Slack integration
        slack_integration = SlackIntegration.create!(
          oauth_access_token: "xoxb-#{Faker::Number.number(digits: 12)}-#{Faker::Number.number(digits: 12)}",
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        Integration.create!(
          integrable: app,
          category: "notification",
          status: "connected",
          providable: slack_integration,
          metadata: {channel: "##{platform}-releases"},
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        # Set up the Version Control integration (GitHub)
        github_integration = GithubIntegration.create!(
          installation_id: Faker::Number.number(digits: 10).to_s,
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        Integration.create!(
          integrable: app,
          category: "version_control",
          status: "connected",
          providable: github_integration,
          metadata: {branch: "main"},
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )

        puts "Created demo app and integrations for #{platform.capitalize}!"
        app
      end
    end

    def setup_train_for_app(app)
      ci_cd_integration = GithubIntegration.create!(
        installation_id: Faker::Number.number(digits: 8).to_s,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        integrable: app,
        category: "ci_cd",
        status: "connected",
        providable: ci_cd_integration,
        metadata: {workflow: "build"},
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Create the train after setting up the integration
      train = Train.create!(
        app: app,
        name: "Demo Train for #{app.name}",
        description: "A train for demo purposes",
        branching_strategy: "almost_trunk",
        working_branch: "main",
        status: "draft",
        kickoff_at: 1.day.from_now,
        repeat_duration: 7.days,
        build_queue_enabled: true,
        build_queue_size: 5,
        build_queue_wait_time: 1.hour,
        versioning_strategy: "semver",
        version_seeded_with: "1.0.0",
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Mocking the workflow call on the CI/CD provider
      GithubIntegration.class_eval do
        def workflows
          [
            {id: "build", name: "Build Workflow"},
            {id: "deploy", name: "Deploy Workflow"}
          ]
        end

        def branch_exists?(branch_name)
          true
        end
      end

      GithubIntegration.define_method(:branch_exists?) { true }
      GithubIntegration.define_method(:workflows) do
        [
          {id: "build", name: "Build Workflow"},
          {id: "deploy", name: "Deploy Workflow"}
        ]
      end

      puts "Set up demo train for #{app.name}!"

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
        platform: app.platform,
        slug: "#{app.platform}-platform-#{app.id}",
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )
    end

    def create_release_platform_steps(release_platform)
      # Ensure that the platform configuration exists
      platform_config = release_platform.platform_config || Config::ReleasePlatform.create!(
        release_platform: release_platform,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Set up the release candidate workflow
      workflow_name = "Release Candidate Workflow"
      rc_ci_cd_channel = release_platform.train.workflows.first || { id: "build", name: "Build Workflow" }

      # Create the beta release configuration
      beta_release = {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "AppStoreSubmission",
            submission_config: "prod",
            rollout_config: { enabled: true, stages: [] },
            auto_promote: false
          }
        ]
      }

      # Create the release platform configuration
      platform_config = Config::ReleasePlatform.create!(
        release_platform: release_platform,
        beta_release: beta_release,
        workflows: {
          internal: nil,
          release_candidate: {
            kind: "release_candidate",
            name: workflow_name,
            id: rc_ci_cd_channel[:id],
            artifact_name_pattern: nil
          }
        },
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Create the build step
      Config::ReleaseStep.create!(
        release_platform_config: platform_config,
        kind: "internal",
        auto_promote: false,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )
    end

    def setup_integrations_for_app(app)
      puts "Creating integrations for #{app.name}..."

      # GitHub (Version Control) Integration
      github_integration = GithubIntegration.create!(
        installation_id: Faker::Number.number(digits: 8).to_s,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        integrable: app,
        category: "version_control",
        status: "connected",
        providable: github_integration,
        metadata: {repository: "demo-org/#{app.platform}-app"},
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # CI/CD Integration (GitHub Actions)
      ci_cd_integration = GithubIntegration.create!(
        installation_id: Faker::Number.number(digits: 8).to_s,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        integrable: app,
        category: "ci_cd",
        status: "connected",
        providable: ci_cd_integration,
        metadata: {repository: "demo-org/#{app.platform}-app", workflow: "build.yml"},
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Slack Integration
      slack_integration = SlackIntegration.create!(
        oauth_access_token: "xoxb-#{Faker::Number.number(digits: 12)}-#{Faker::Number.number(digits: 12)}",
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        integrable: app,
        category: "notification",
        status: "connected",
        providable: slack_integration,
        metadata: {channel: "##{app.platform}-releases"},
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Store Integration (Google Play or App Store)
      store_integration = if app.platform == "android"
        GooglePlayStoreIntegration.create!(
          json_key: "{ \"type\": \"service_account\", \"project_id\": \"demo-android-app-#{Faker::Number.number(digits: 6)}\" }",
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )
      else
        AppStoreIntegration.create!(
          key_id: "A#{Faker::Number.hexadecimal(digits: 10)}",
          issuer_id: Faker::Number.hexadecimal(digits: 8).to_s,
          p8_key: "-----BEGIN PRIVATE KEY-----\nMIIE#{Faker::Lorem.characters(number: 1000)}\n-----END PRIVATE KEY-----",
          created_at: 1.year.ago,
          updated_at: 1.year.ago
        )
      end

      Integration.create!(
        integrable: app,
        category: "app_store",
        status: "connected",
        providable: store_integration,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      # Error Tracking Integration (Bugsnag)
      bugsnag_integration = BugsnagIntegration.create!(
        access_token: Faker::Crypto.md5,
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      Integration.create!(
        integrable: app,
        category: "error_tracking",
        status: "connected",
        providable: bugsnag_integration,
        metadata: {project_id: Faker::Number.number(digits: 10).to_s},
        created_at: 1.year.ago,
        updated_at: 1.year.ago
      )

      puts "Integrations set up for #{app.name}!"
    end

    def setup_releases_and_commits(app, build_step, release_platform, train)
      num_releases = rand(size_config[:releases])
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
      version_parts = current_version.split(".")
      if i % 3 == 0 && i > 0
        version_parts[1] = (version_parts[1].to_i + 1).to_s
        version_parts[2] = "0"
      else
        version_parts[2] = (version_parts[2].to_i + 1).to_s
      end
      current_version = version_parts.join(".")

      release_start_date = (i + 1).months.ago
      release_end_date = release_start_date + 2.weeks

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

      ReleaseMetadata.create!(
        release: release,
        release_platform_run: release_platform_run,
        locale: "en-US",
        release_notes: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
        default_locale: true,
        created_at: release_start_date,
        updated_at: release_start_date
      )

      step_run = Steps.create!(
        train: train,
        name: "Build Step #{i + 1}",
        description: "Automated build step for version #{current_version}",
        status: if release_statuses[i] == "completed"
                  "completed"
                else
                  (release_statuses[i] == "running") ? "running" : "pending"
                end,
        step_number: 1,
        run_after_duration: "00:30:00", # Placeholder for duration
        ci_cd_channel: {type: "github_actions", workflow: "build.yml"},
        build_artifact_channel: {type: "artifact", path: "path/to/artifact"},
        slug: "build-step-#{i + 1}",
        created_at: release_start_date,
        updated_at: [release_end_date, Time.zone.now].min
      )

      num_commits = rand(size_config[:commits_per_release])

      if release_statuses[i] == "completed" || release_statuses[i] == "running"
        build = Build.create!(
          release_platform_run: release_platform_run,
          version_name: current_version,
          build_number: (i + 100).to_s,
          generated_at: release_start_date + 1.day,
          created_at: release_start_date + 1.day,
          updated_at: release_start_date + 1.day,
          sequence_number: i + 1
        )

        BuildArtifact.create!(
          step_run: step_run,
          build: build,
          generated_at: release_start_date + 1.day,
          uploaded_at: release_start_date + 1.day,
          created_at: release_start_date + 1.day,
          updated_at: release_start_date + 1.day
        )

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

      commit_start_date = release_start_date - 1.week
      commit_end_date = release_start_date

      if num_commits.is_a?(Integer)
        num_commits.times do |j|
          commit_date = random_date(commit_start_date, commit_end_date)

          author = Accounts::User.all.sample

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
