# # rubocop:disable Rails/Output
#
# # TODO:
# # using schema.rb, create a demo organization
# # it should have 2 teams and 4 members in each team
# # there should be 2 apps - one android and the other ios
# # each app should have 10 - 15  historical releases
# # 50 - 60 commits per release
# # 1 release should be upcoming status and 1 should be running status, and the rest are completed (maybe a fraction of it could be stopped) - for each app
# # integrations should be setup for each app - 1 version control, 1 build server (both can be github), 1 slack, 1 playstore (for the android app), 1 app store (for the ios app), 1 bugsnag
#
# require "faker"
#
# module Seed
#   class DemoStarter
#     include Seed::Constants
#
#     SIZES = {
#       small: {releases: 5, commits: 20},
#       medium: {releases: 12, commits: 50},
#       large: {releases: 20, commits: 100}
#     }.freeze
#
#     def self.call(size: :medium)
#       new(size).call
#     end
#
#     def initialize(size)
#       @size = size
#       @config = SIZES[@size]
#     end
#
#     def call
#       puts "Cleaning existing demo data..."
#       clean_data
#
#       puts "Creating demo organization..."
#       organization = create_organization
#
#       puts "Creating admin user..."
#       create_admin_user(organization)
#
#       puts "Creating teams..."
#       teams = create_teams(organization)
#
#       puts "Creating team members..."
#       create_team_members(teams, organization)
#
#       puts "Creating apps (Android and iOS)..."
#       apps = create_apps(organization)
#
#       apps.each do |app|
#         puts "Setting up train for #{app.name}..."
#         setup_train_for_app(app)
#
#         puts "Setting up integrations for #{app.name}..."
#         setup_integrations_for_app(app)
#
#         puts "Creating releases and commits for #{app.name}..."
#         setup_releases_and_commits(app)
#       end
#
#       puts "Demo data setup completed!"
#     end
#
#     private
#
#     def clean_data
#       Commit.delete_all
#       PullRequest.delete_all
#       BuildArtifact.delete_all
#       Build.delete_all
#       ReleaseMetadata.delete_all
#       ReleasePlatformRun.delete_all
#       ReleasePlatform.delete_all
#       Release.delete_all
#       Steps.delete_all
#       Integration.delete_all
#       AppConfig.delete_all
#       ReleaseIndexComponent.delete_all
#       ReleaseIndex.delete_all
#       Train.delete_all
#       App.delete_all
#       Accounts::Membership.delete_all
#       Accounts::Team.delete_all
#       Accounts::UserAuthentication.delete_all
#       Accounts::User.delete_all
#       Accounts::Organization.delete_all
#     end
#
#     def create_organization
#       Accounts::Organization.create!(
#         name: "Demo Organization",
#         slug: "demo-org",
#         status: "active",
#         created_by: "admin@example.com"
#       )
#     end
#
#     def create_admin_user(organization)
#       admin_user = Accounts::User.create!(
#         full_name: "Demo Admin User",
#         preferred_name: "Demo Admin",
#         unique_authn_id: "demo.admin@example.com",
#         slug: "admin-user",
#         admin: true
#       )
#
#       Accounts::EmailAuthentication.create!(
#         email: "demo.admin@example.com",
#         password: ADMIN_PASSWORD,
#         confirmed_at: Time.zone.now,
#         user: admin_user
#       )
#
#       Accounts::Membership.create!(
#         user: admin_user,
#         organization: organization,
#         role: "owner"
#       )
#
#       nil
#     end
#
#     def create_teams(organization)
#       %w[Team\ Blue Team\ Green].map do |team_name|
#         Accounts::Team.create!(
#           organization: organization,
#           name: team_name,
#           color: Faker::Color.color_name
#         )
#       end
#     end
#
#     def create_team_members(teams, organization)
#       teams.each do |team|
#         4.times do
#           user = Accounts::User.create!(
#             full_name: Faker::Name.name,
#             preferred_name: Faker::Name.first_name,
#             unique_authn_id: Faker::Internet.email,
#             slug: Faker::Internet.username
#           )
#
#           Accounts::EmailAuthentication.create!(
#             email: user.unique_authn_id,
#             password: DEVELOPER_PASSWORD,
#             confirmed_at: Time.zone.now,
#             user: user
#           )
#
#           Accounts::Membership.create!(
#             user: user,
#             organization: organization,
#             team: team,
#             role: "developer"
#           )
#         end
#       end
#     end
#
#     def create_apps(organization)
#       %w[android ios].map do |platform|
#         App.create!(
#           organization: organization,
#           name: "Demo #{platform.capitalize} App",
#           description: "Demo app for #{platform}",
#           platform: platform,
#           bundle_identifier: "com.demo.#{platform}",
#           build_number: 1,
#           timezone: "UTC"
#         )
#       end
#     end
#
#     def setup_train_for_app(app)
#       branching_strategy = %w[almost_trunk release_backmerge parallel_working].sample
#       Train.create!(
#         app: app,
#         name: "Main Train",
#         status: "active",
#         branching_strategy: branching_strategy,
#         working_branch: "main",
#         version_seeded_with: "1.0.0",
#         version_current: "1.0.0"
#       )
#     end
#
#     def setup_integrations_for_app(app)
#       Integration.create!(
#         integrable: app,
#         category: "version_control",
#         status: "connected",
#         providable: GithubIntegration.create!(installation_id: Faker::Number.number(digits: 10))
#       )
#
#       Integration.create!(
#         integrable: app,
#         category: "notification",
#         status: "connected",
#         providable: SlackIntegration.create!(oauth_access_token: Faker::Crypto.md5)
#       )
#
#       Integration.create!(
#         integrable: app,
#         category: "error_tracking",
#         status: "connected",
#         providable: BugsnagIntegration.create!(access_token: Faker::Crypto.md5)
#       )
#     end
#
#     def setup_releases_and_commits(app)
#       release_statuses = ["completed"] * (@config[:releases] - 2) + %w[upcoming running]
#       release_statuses.shuffle!
#
#       @config[:releases].times do |i|
#         release = Release.create!(
#           train: Train.first,
#           branch_name: "release/v#{i + 1}.0.0",
#           status: release_statuses[i],
#           release_version: "v#{i + 1}.0.0"
#         )
#
#         create_commits_for_release(app, release)
#       end
#     end
#
#     def create_commits_for_release(app, release)
#       @config[:commits].times do
#         Commit.create!(
#           release: release,
#           commit_hash: Faker::Crypto.sha1,
#           message: Faker::Lorem.sentence,
#           author_name: Faker::Name.name,
#           author_email: Faker::Internet.email,
#           timestamp: Time.zone.now
#         )
#       end
#     end
#   end
# end
#
# # module Seed
# #   class DemoStarter
# #     SIZES = {
# #       small: {releases: 5, commits: 20},
# #       medium: {releases: 12, commits: 50},
# #       large: {releases: 20, commits: 100}
# #     }.freeze
# #
# #     def self.call(size: :medium)
# #       new(size).call
# #     end
# #
# #     def initialize(size)
# #       @size = size
# #       @config = SIZES[@size]
# #     end
# #
# #     def random_uuid
# #       SecureRandom.uuid
# #     end
# #
# #     # def clean_database
# #     #   Rake::Task["db:nuke_app"].invoke
# #     #   puts "🗑️  Database cleaned successfully!"
# #     # end
# #
# #     def create_organization(name)
# #       Organization.create!(
# #         name: name,
# #         slug: name.parameterize,
# #         status: "active",
# #         created_by: "seed_script"
# #       )
# #     end
# #
# #     def create_team(org, name, color)
# #       Team.create!(organization: org, name: name, color: color)
# #     end
# #
# #     def create_user(full_name, email)
# #       User.create!(
# #         full_name: full_name,
# #         email: email,
# #         encrypted_password: Devise::Encryptor.digest(User, "password123"),
# #         confirmed_at: Time.current,
# #         unique_authn_id: random_uuid
# #       )
# #     end
# #
# #     def create_app(org, name, platform)
# #       App.create!(
# #         organization: org,
# #         name: name,
# #         platform: platform,
# #         bundle_identifier: "#{org.slug}.#{name.downcase}",
# #         build_number: 1000,
# #         timezone: "UTC"
# #       )
# #     end
# #
# #     def create_integration(app, category, integration_details)
# #       Integration.create!(
# #         app: app,
# #         category: category,
# #         status: "connected",
# #         metadata: integration_details
# #       )
# #     end
# #
# #     def create_release(train, branch, status, scheduled_at)
# #       Release.create!(
# #         train: train,
# #         branch_name: branch,
# #         status: status,
# #         scheduled_at: scheduled_at
# #       )
# #     end
# #
# #     def create_commits(release, num_commits)
# #       commit_attrs = Array.new(num_commits) do
# #         {
# #           commit_hash: SecureRandom.hex(20),
# #           release_id: release.id,
# #           message: Faker::Lorem.sentence(word_count: 8),
# #           timestamp: Faker::Time.backward(days: 30),
# #           author_name: Faker::Name.name,
# #           author_email: Faker::Internet.email,
# #           url: Faker::Internet.url,
# #           created_at: Time.current,
# #           updated_at: Time.current
# #         }
# #       end
# #
# #       Commit.insert_all!(commit_attrs)
# #     end
# #
# #     def call
# #       puts "Starting seeding process..."
# #       clean_database
# #
# #       ActiveRecord::Base.transaction do
# #         puts " Creating organization..."
# #         org = create_organization("Demo Organization")
# #         puts " Organization created: #{org.name}"
# #
# #         colors = %w[#FF5733 #33FF57]
# #         colors.each.with_index(1) do |color, idx|
# #           puts " Creating Team #{idx}..."
# #           team = create_team(org, "Team #{idx}", color)
# #           4.times do |user_idx|
# #             puts "Creating user #{user_idx + 1} for Team #{idx}..."
# #             user = create_user(Faker::Name.name, Faker::Internet.unique.email)
# #             Membership.create!(user: user, organization: org, team: team, role: "developer")
# #           end
# #           puts "eam #{idx} and users created."
# #         end
# #
# #         apps = {
# #           android: create_app(org, "DemoAndroidApp", "android"),
# #           ios: create_app(org, "DemoiOSApp", "ios")
# #         }
# #
# #         apps.each do |platform, app|
# #           puts "Setting up integrations for #{app.name}..."
# #           github_details = {installation_id: Faker::Number.number(digits: 8)}
# #           slack_details = {oauth_access_token: SecureRandom.hex(16)}
# #           bugsnag_details = {access_token: SecureRandom.hex(32)}
# #
# #           create_integration(app, "version_control", github_details)
# #           create_integration(app, "build_server", github_details)
# #           create_integration(app, "notification_channel", slack_details)
# #           create_integration(app, "bugsnag", bugsnag_details)
# #
# #           if platform == :android
# #             playstore_details = {json_key: SecureRandom.hex(32)}
# #             create_integration(app, "play_store", playstore_details)
# #           else
# #             appstore_details = {
# #               key_id: SecureRandom.hex(8),
# #               p8_key: SecureRandom.hex(32),
# #               issuer_id: SecureRandom.hex(8)
# #             }
# #             create_integration(app, "app_store", appstore_details)
# #           end
# #           puts "Integrations set for #{app.name}."
# #
# #           puts "Creating train for #{app.name}..."
# #           train = Train.create!(
# #             app: app,
# #             name: "#{app.name} Train",
# #             status: "active",
# #             branching_strategy: "release_branch",
# #             release_branch: "main",
# #             working_branch: "develop",
# #             kickoff_at: Time.current,
# #             repeat_duration: "7 days"
# #           )
# #           puts "Train created: #{train.name}"
# #
# #           total_releases = @config[:releases]
# #           statuses = %w[upcoming running]
# #           completed_count = total_releases - statuses.size
# #           completed_releases = Array.new(completed_count, "completed")
# #           completed_releases.sample([1, completed_count / 4].min).each { |status| status.replace("stopped") }
# #           statuses += completed_releases
# #           statuses.shuffle!
# #
# #           statuses.each_with_index do |status, idx|
# #             scheduled_at = case status
# #             when "upcoming"
# #               Faker::Time.forward(days: 5)
# #             when "running"
# #               Time.current
# #             else
# #               Faker::Time.backward(days: 60 - idx)
# #             end
# #
# #             puts "Creating release #{idx + 1} (#{status})..."
# #             release = create_release(train, "release/#{idx + 1}", status, scheduled_at)
# #
# #             puts " Creating #{@config[:commits]} commits for release #{idx + 1}..."
# #             create_commits(release, @config[:commits])
# #             puts " Release #{idx + 1} and commits created."
# #           end
# #         end
# #       end
# #       puts " Seeding complete!"
# #     rescue => e
# #       Rails.logger.error("Seeding failed: #{e.message}")
# #       puts "Seeding failed: #{e.message}. Check logs for details."
# #     end
# #   end
# # end
#
# # rubocop:enable Rails/Output

# rubocop:disable Rails/Output

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
        {teams: 1, members_per_team: 4, releases: 5..8, commits_per_release: 20..30}
      when "medium"
        {teams: 2, members_per_team: 4, releases: 10..15, commits_per_release: 50..60}
      when "large"
        {teams: 3, members_per_team: 8, releases: 20..25, commits_per_release: 80..100}
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
        size_config[:members_per_team].times do |i|
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
          @branch_name = branch_name
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
      create_release_platform_steps(release_platform)
      setup_integrations_for_app(app)

      setup_releases_and_commits(app, release_platform, train)
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
      # Set up the release candidate workflow
      workflow_name = "Release Candidate Workflow"
      rc_ci_cd_channel = release_platform.train.workflows.first || {id: "build", name: "Build Workflow"}

      # Create the beta release configuration
      beta_release = {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "AppStoreSubmission",
            submission_config: "prod",
            rollout_config: {enabled: true, stages: []},
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

      nil
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

    def setup_releases_and_commits(app, release_platform, train)
      num_releases = rand(size_config[:releases])
      release_statuses = ["completed"] * (num_releases - 2) + %w[upcoming running]

      num_stopped = (num_releases * 0.2).to_i
      release_statuses[0...num_stopped] = ["stopped"] * num_stopped

      release_statuses.shuffle!
      # current_version = "1.0.0"

      if num_releases.is_a?(Integer)
        num_releases.times do |i|
          # create_commit_for_release(app, current_version, i, release_platform, release_statuses, train)
        end
      end
    end
  end
end
