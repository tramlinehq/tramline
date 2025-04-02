# rubocop:disable Rails/Output

module Seed
  class DemoStarter
    include Seed::Constants

    SIZE_CONFIGS = {
      small: {
        team_count: 1,
        users_per_team: 2,
        app_count: 1,
        release_count: (5..7),
        commits_per_release: (20..30),
        workflow_runs_per_release: 1
      },
      medium: {
        team_count: 2,
        users_per_team: 4,
        app_count: 2,
        release_count: (12..15),
        commits_per_release: (50..60),
        workflow_runs_per_release: 2
      },
      large: {
        team_count: 3,
        users_per_team: 6,
        app_count: 3,
        release_count: (20..25),
        commits_per_release: (100..150),
        workflow_runs_per_release: 3
      }
    }.freeze

    TEAM_NAMES = ["Engineering", "Product"]
    TEAM_COLORS = ["#FF5733", "#33FF57", "#3357FF", "#FF33F6", "#33FFF6"]

    USER_NAMES = [
      {full_name: "Alex Johnson", preferred_name: "Alex"},
      {full_name: "Sam Williams", preferred_name: "Sam"},
      {full_name: "Jamie Parker", preferred_name: "Jamie"},
      {full_name: "Taylor Smith", preferred_name: "Taylor"},
      {full_name: "Morgan Lee", preferred_name: "Morgan"},
      {full_name: "Casey Brown", preferred_name: "Casey"},
      {full_name: "Riley Wilson", preferred_name: "Riley"},
      {full_name: "Jordan Davis", preferred_name: "Jordan"},
      {full_name: "Drew Anderson", preferred_name: "Drew"},
      {full_name: "Jordan Taylor", preferred_name: "Jordan"},
      {full_name: "Morgan Parker", preferred_name: "Morgan"},
      {full_name: "Riley Johnson", preferred_name: "Riley"},
      {full_name: "Casey Smith", preferred_name: "Casey"},
      {full_name: "Taylor Wilson", preferred_name: "Taylor"},
      {full_name: "Jamie Brown", preferred_name: "Jamie"},
      {full_name: "Sam Davis", preferred_name: "Sam"},
      {full_name: "Alex Lee", preferred_name: "Alex"},
      {full_name: "Drew Williams", preferred_name: "Drew"}
    ]

    APP_NAMES = ["ShopSmart", "FitTracker", "TaskMaster", "WeatherPro", "RecipeHub"]
    APP_PLATFORMS = ["android", "ios"]
    APP_BUNDLE_IDS = [
      "com.tramline.demo.shopsmart",
      "com.tramline.demo.fittracker",
      "com.tramline.demo.taskmaster",
      "com.tramline.demo.weatherpro",
      "com.tramline.demo.recipehub"
    ]

    RELEASE_STATUSES = ["completed", "completed", "completed", "completed", "stopped", "completed", "completed", "completed"]
    BOOLEAN_OPTIONS = [true, false]

    def self.call(size = :medium)
      new(size).call
    end

    def initialize(size = :medium)
      @size = size.to_sym
      @config = SIZE_CONFIGS[@size] || SIZE_CONFIGS[:medium]
    end

    def call
      clear_database

      puts "Seeding database with #{@size} demo data..."

      ActiveRecord::Base.transaction do
        organization = create_demo_organization
        teams = create_teams(organization)
        create_users(organization, teams)
        apps = create_apps(organization)
        setup_integrations(apps)
        create_releases_and_commits(apps)
      end

      puts "[size: #{@size}]: Completed seeding demo database"
    end

    private

    def clear_database
      puts "Clearing database..."
      Rake::Task["db:clear_for_demo"].invoke
    end

    def create_demo_organization
      admin_user = Accounts::User.find_by(email: ADMIN_EMAIL) ||
        Accounts::User.find_by(unique_authn_id: ADMIN_EMAIL)

      org = Accounts::Organization.find_or_initialize_by(
        name: "Tramline Demo Organization",
        status: Accounts::Organization.statuses[:active],
        created_by: admin_user ? admin_user.email : ADMIN_EMAIL
      )

      org.api_key = "demo-#{SecureRandom.hex(10)}" unless org.persisted?
      org.save!

      puts "Created demo organization: #{org.name}"
      org
    end

    def create_teams(organization)
      teams = []

      @config[:team_count].times do |index|
        team = Accounts::Team.find_or_create_by!(
          name: "Team #{index + 1}",
          organization: organization,
          color: TEAM_COLORS[index]
        )
        teams << team
        puts "Created team: #{team.name}"
      end

      teams
    end

    def create_users(organization, teams)
      users = []

      @config[:users_per_team].times do |index|
        user_data = USER_NAMES[index]
        email = "demo.#{user_data[:preferred_name].downcase}@tramline.app"
        password = "demo-password"

        email_authentication = Accounts::EmailAuthentication.find_or_initialize_by(email: email)

        if email_authentication.persisted?
          user = email_authentication.user
        else
          user = Accounts::User.find_or_create_by!(
            full_name: user_data[:full_name],
            preferred_name: user_data[:preferred_name],
            unique_authn_id: email
          )

          email_authentication.password = password
          email_authentication.confirmed_at = DateTime.now
          email_authentication.save!

          Accounts::UserAuthentication.create!(
            user: user,
            authenticatable: email_authentication
          )
        end

        team = teams[index % teams.size]

        unless Accounts::Membership.exists?(user: user, organization: organization)
          role = (index == 0) ? :owner : :developer
          Accounts::Membership.find_or_create_by!(
            user: user,
            organization: organization,
            team: team,
            role: Accounts::Membership.roles[role]
          )
        end

        users << user
        puts "Created user: #{user.full_name} (#{email}) in team #{team.name}"
      end

      users
    end

    def create_apps(organization)
      apps = []

      @config[:app_count].times do |index|
        name = APP_NAMES[index]
        platform = APP_PLATFORMS[index % APP_PLATFORMS.size]
        bundle_id = APP_BUNDLE_IDS[index]

        app = App.find_or_create_by!(
          name: name,
          organization: organization,
          platform: platform,
          bundle_identifier: bundle_id,
          build_number: 1,
          timezone: "UTC",
          description: "Demo #{platform} app for Tramline"
        )

        app.update_column(:external_id, "demo-app-#{SecureRandom.hex(4)}") # rubocop:disable Rails/SkipsModelValidations

        unless AppConfig.exists?(app: app)
          AppConfig.create!(
            app: app,
            code_repository: {url: "https://github.com/tramlineapp/#{name.downcase}"},
            notification_channel: {slack_channel: "##{name.downcase}-releases"}
          )
        end

        apps << app
        puts "Created app: #{app.name} (#{app.platform})"
      end

      apps
    end

    def setup_integrations(apps)
      apps.each do |app|
        github_providable = GithubIntegration.new(installation_id: "12345678")
        github_providable.save(validate: false)

        github_integration = Integration.new(
          integrable: app,
          integrable_type: "App",
          category: "version_control",
          status: "connected",
          providable: github_providable
        )
        github_integration.save(validate: false)

        github_providable.instance_variable_set(:@integration, github_integration)

        slack_providable = SlackIntegration.new(oauth_access_token: "xoxp-demo-token-#{SecureRandom.hex(8)}")
        slack_providable.save(validate: false)

        slack_integration = Integration.new(
          integrable: app,
          integrable_type: "App",
          category: "notification",
          status: "connected",
          providable: slack_providable
        )
        slack_integration.save(validate: false)

        slack_providable.instance_variable_set(:@integration, slack_integration)

        bugsnag_providable = BugsnagIntegration.new(access_token: "bugsnag-demo-token-#{SecureRandom.hex(8)}")
        bugsnag_providable.save(validate: false)

        bugsnag_integration = Integration.new(
          integrable: app,
          integrable_type: "App",
          category: "monitoring",
          status: "connected",
          providable: bugsnag_providable,
          metadata: [{"name" => "Demo Organization", "id" => "demo-org-id", "slug" => "demo-org"}]
        )
        bugsnag_integration.save(validate: false)

        bugsnag_providable.instance_variable_set(:@integration, bugsnag_integration)

        if app.platform == "ios"
          AppStoreIntegration.skip_callback(:create, :before, :set_external_details_on_app)

          app_store_providable = AppStoreIntegration.new(
            key_id: "DEMO_KEY_ID",
            issuer_id: "DEMO_ISSUER_ID",
            p8_key: "-----BEGIN PRIVATE KEY-----\nDEMO_KEY\n-----END PRIVATE KEY-----"
          )
          app_store_providable.save(validate: false)

          AppStoreIntegration.set_callback(:create, :before, :set_external_details_on_app)

          app_store_integration = Integration.new(
            integrable: app,
            integrable_type: "App",
            category: "build_channel",
            status: "connected",
            providable: app_store_providable
          )
          app_store_integration.save(validate: false)
          app_store_providable.instance_variable_set(:@integration, app_store_integration)
        end

        if app.platform == "android"
          play_store_providable = GooglePlayStoreIntegration.new(
            json_key: '{"type":"service_account","project_id":"demo-project","client_email":"demo@example.com"}'
          )
          play_store_providable.save(validate: false)

          play_store_integration = Integration.new(
            integrable: app,
            integrable_type: "App",
            category: "build_channel",
            status: "connected",
            providable: play_store_providable
          )
          play_store_integration.save(validate: false)

          play_store_providable.instance_variable_set(:@integration, play_store_integration)
        end

        puts "Created integrations for app: #{app.name}"
      end
    end

    def create_releases_and_commits(apps)
      apps.each do |app|
        train = MockTrain.new(
          app: app,
          name: "#{app.name} Release Train",
          status: "active",
          branching_strategy: "almost_trunk",
          working_branch: "develop",
          version_seeded_with: "1.0.0",
          version_current: "1.0.0"
        )

        train.save(validate: false)

        puts "Created train: #{train.name} for app: #{app.name}"

        release_platform = MockReleasePlatform.new(
          app: app,
          name: "#{app.platform.capitalize} Platform",
          train: train,
          platform: app.platform
        )

        release_platform.save(validate: false)

        rc_ci_cd_channel = {id: "build", name: "Build"}
        base_config_map = {
          release_platform: release_platform,
          workflows: {
            internal: nil,
            release_candidate: {
              kind: "release_candidate",
              name: rc_ci_cd_channel[:name],
              id: rc_ci_cd_channel[:id],
              artifact_name_pattern: nil
            }
          },
          internal_release: nil,
          beta_release: {
            auto_promote: false,
            submissions: []
          }
        }

        platform_config = Config::ReleasePlatform.from_json(base_config_map)
        platform_config.release_platform = release_platform
        platform_config.save(validate: false)

        release_platform.platform_config = platform_config
        release_platform.save(validate: false)

        release_index = ReleaseIndex.new(
          train: train,
          tolerable_range: "[0,10)"
        )
        release_index.save(validate: false)

        puts "Created release platform: #{release_platform.name} for app: #{app.name}"

        release_count = rand(@config[:release_count])

        release_count.times do |i|
          version = "1.#{i / 5}.#{i % 5}"

          status = if i == release_count - 1
            "created"
          elsif i == release_count - 2
            "on_track"
          elsif i == release_count - 3 && rand < 0.3
            "stopped"
          else
            "finished"
          end

          release = Release.new(
            train: train,
            branch_name: "release/#{version}",
            status: status,
            original_release_version: version,
            scheduled_at: (release_count - i).weeks.ago,
            completed_at: (status == "finished") ? (release_count - i - 1).weeks.ago : nil,
            stopped_at: (status == "stopped") ? (release_count - i - 1).weeks.ago : nil,
            is_automatic: BOOLEAN_OPTIONS.sample,
            release_type: "release",
            slug: "release-#{version}-#{SecureRandom.hex(4)}"
          )

          Release.skip_callback(:create, :before, :set_version)
          release.save(validate: false)
          Release.set_callback(:create, :before, :set_version)

          release_platform_run = ReleasePlatformRun.new(
            release_platform: release_platform,
            release: release,
            code_name: "#{app.name} #{version}",
            scheduled_at: (release_count - i).weeks.ago,
            status: status,
            release_version: version,
            completed_at: (status == "finished") ? (release_count - i - 1).weeks.ago : nil,
            stopped_at: (status == "stopped") ? (release_count - i - 1).weeks.ago : nil
          )

          release_platform_run.save(validate: false)
          commit_count = rand(@config[:commits_per_release])
          last_commit = nil

          commit_count.times do |j|
            commit = Commit.new(
              release_platform_id: release_platform.id,
              release: release,
              release_platform_run_id: release_platform_run.id,
              commit_hash: SecureRandom.hex(20),
              message: "feat: Demo commit #{j + 1} for release #{version}",
              timestamp: (release_count - i).weeks.ago + (j.to_f / commit_count).days,
              author_name: USER_NAMES.sample[:full_name],
              author_email: "demo.user#{j % 8}@tramline.app",
              url: "https://github.com/tramlineapp/#{app.name.downcase}/commit/#{SecureRandom.hex(20)}"
            )

            commit.save(validate: false)
            last_commit = commit
          end

          if last_commit && status != "created"
            @config[:workflow_runs_per_release].times do |workflow_index|
              workflow_commit = Commit.new(
                release_platform_id: release_platform.id,
                release: release,
                release_platform_run_id: release_platform_run.id,
                commit_hash: SecureRandom.hex(20),
                message: "feat: Demo workflow commit #{workflow_index + 1} for release #{version}",
                timestamp: (release_count - i).weeks.ago + (workflow_index + 1).hours,
                author_name: USER_NAMES.sample[:full_name],
                author_email: "demo.user#{workflow_index % 8}@tramline.app",
                url: "https://github.com/tramlineapp/#{app.name.downcase}/commit/#{SecureRandom.hex(20)}"
              )

              workflow_commit.save(validate: false)

              pre_prod_release = PreProdRelease.new(
                release_platform_run: release_platform_run,
                commit: workflow_commit,
                type: "InternalRelease",
                status: "created"
              )

              pre_prod_release.save(validate: false)

              workflow_run = WorkflowRun.new(
                release_platform_run: release_platform_run,
                commit: workflow_commit,
                pre_prod_release_id: pre_prod_release.id,
                status: "finished",
                kind: "release_candidate",
                started_at: (release_count - i).weeks.ago + (workflow_index + 1).hours,
                finished_at: (release_count - i).weeks.ago + (workflow_index + 2).hours,
                workflow_config: {
                  "id" => "build",
                  "name" => "Build",
                  "kind" => "release_candidate",
                  "artifact_name_pattern" => nil,
                  "build_suffix" => nil,
                  "parameters" => []
                }
              )
              workflow_run.save(validate: false)

              build = Build.new(
                release_platform_run: release_platform_run,
                commit: workflow_commit,
                workflow_run: workflow_run,
                version_name: version,
                build_number: i + 1,
                generated_at: (release_count - i).weeks.ago + (workflow_index + 2).hours
              )

              build.save(validate: false)

              if status == "finished" || status == "on_track"
                store_submission_type = (app.platform == "ios") ? "AppStoreSubmission" : "PlayStoreSubmission"
                submission_status = if app.platform == "ios"
                  (status == "finished") ? "approved" : "submitted_for_review"
                else
                  (status == "finished") ? "prepared" : "preprocessing"
                end

                store_submission = Object.const_get(store_submission_type).new(
                  release_platform_run: release_platform_run,
                  build: build,
                  status: submission_status,
                  submitted_at: (status == "finished") ? (release_count - i - 1).weeks.ago - 3.days : nil,
                  approved_at: (status == "finished") ? (release_count - i - 1).weeks.ago - 1.day : nil
                )

                store_submission.save(validate: false)
                if status == "finished"
                  # Only create an active production release if there isn't one already
                  unless ProductionRelease.exists?(release_platform_run: release_platform_run, status: "active")
                    production_release = ProductionRelease.new(
                      release_platform_run: release_platform_run,
                      build: build,
                      status: "active"
                    )
                    production_release.save(validate: false)
                  end
                end
              end
            end
          end

          puts "Created release #{version} for #{app.name} with #{commit_count} commits (status: #{status})"
        end
      end
    end
  end
end

# rubocop:enable Rails/Output
