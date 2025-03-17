class Triggers::PreRelease
  class AlmostTrunk
    include Memery

    def self.call(release, release_branch, bump_version: true)
      new(release, release_branch).call(bump_version:)
    end

    def initialize(release, release_branch)
      @release = release
      @release_branch = release_branch
    end

    def call(bump_version: true)
      if bump_version && version_bump_enabled?
        create_bump_version_branch
          .then { create_bump_version_pr }
          .then { create_default_release_branch }
      else
        create_default_release_branch
      end
    end

    private

    attr_reader :release, :release_branch
    delegate :train, :hotfix?, :new_hotfix_branch?, :release_version, to: :release
    delegate :working_branch, :version_bump_enabled?, to: :train
    delegate :logger, to: Rails

    def create_default_release_branch
      source =
        if hotfix_branch?
          {
            ref: release.hotfixed_from.end_ref,
            type: :tag
          }
        else
          {
            ref: working_branch,
            type: :branch
          }
        end
      stamp_data = {working_branch: source[:ref], release_branch:}
      stamp_type = :release_branch_created
      create_branch(source[:ref], release_branch, source[:type], stamp_data, stamp_type)
    end

    def create_bump_version_branch
      stamp_data = {version_bump_branch:, release_version:}
      stamp_type = :version_bump_branch_created
      create_branch(working_branch, version_bump_branch, :branch, stamp_data, stamp_type)
    end

    def create_branch(from, to, type, stamp_data, stamp_type)
      GitHub::Result.new do
        train.create_branch!(from, to, source_type: type).then do |value|
          release.event_stamp_now!(reason: stamp_type, kind: :success, data: stamp_data)
          value
        end
      rescue Installations::Error => ex
        if ex.reason == :tag_reference_already_exists
          logger.debug { "Pre-release branch already exists: #{release_branch}" }
        else
          raise ex
        end
      end
    end

    def create_bump_version_pr
      GitHub::Result.new do
        # Use configured build files or fall back to finding them
        build_files = train.version_bump_file_paths
        return if build_files.empty?

        # Update version in each build file on the version branch
        updated_files = []
        build_files.each do |file_path|
          file_result = update_version_in_file(version_bump_branch, file_path)
          updated_files << file_path if file_result
        end

        unless updated_files.any?
          release.event_stamp_now!(reason: :version_bump_no_changes, kind: :notice, data: {release_version:})
          return
        end

        pr_title = "Bump version to #{release_version}"
        pr_body = <<~BODY
          🎉 A new release #{release_version} has kicked off!

          This PR updates the version number in `#{updated_files.join(", ")}` to prepare for our #{release_version} release.

          All aboard the release train!
        BODY

        result = Triggers::PullRequest.create_and_merge!(
          release: release,
          new_pull_request: release.pull_requests.version_bump.open.build,
          to_branch_ref: working_branch,
          from_branch_ref: version_bump_branch,
          title: pr_title,
          description: pr_body,
          error_result_on_auto_merge: true
        )

        if result.ok?
          release.event_stamp_now!(reason: :version_bump_pr_created, kind: :notice, data: {release_version:})
        else
          release.event_stamp_now!(reason: :version_bump_pr_failed, kind: :error, data: {error: result.error})
        end

        result.value!
      end
    end

    def update_version_in_file(branch, file_path)
      # Get the current file content
      content = train.vcs_provider.get_file_content(branch, file_path)

      # Update version based on file type
      updated_content =
        if file_path.end_with?(".gradle")
          update_gradle_version(content)
        elsif file_path.end_with?(".plist")
          update_plist_version(content)
        elsif file_path.end_with?(".pbxproj")
          update_pbxproj_version(content)
        elsif file_path == "pubspec.yaml"
          update_pubspec_version(content)
        else
          content # No change for unknown file types
        end

      # Write back if changed
      if content != updated_content
        train.vcs_provider.update_file(
          branch,
          file_path,
          updated_content,
          "Bump version to #{release_version}",
          author_name: "Tramline",
          author_email: "tramline-bot@tramline.app"
        )
      end
    end

    # Update version in pubspec.yaml (flutter)
    # The version line typically looks like: version: 1.2.3+45
    # We want to update the semantic version part (1.2.3) but keep the build number (+45) if present
    def update_pubspec_version(content)
      content.gsub(/^version:\s*(\d+\.\d+\.\d+)(\+\d+)?/) do
        build_number = $2 || ""
        "version: #{release_version}#{build_number}"
      end
    end

    def update_gradle_version(content)
      # For Android build.gradle files
      version_name = release.release_version
      version_code = train.app.bump_build_number!(release_version: version_name)

      # Update versionName
      content = content.gsub(/versionName\s+["'].*?["']/, "versionName \"#{version_name}\"")

      # Update versionCode
      content.gsub(/versionCode\s+\d+/, "versionCode #{version_code}")
    end

    def update_plist_version(content)
      # For iOS Info.plist files
      version = release.release_version
      build_number = train.app.bump_build_number!(release_version: version)

      content = content.gsub(/<key>CFBundleShortVersionString<\/key>\s*<string>.*?<\/string>/,
        "<key>CFBundleShortVersionString</key>\n\t<string>#{version}</string>")

      content.gsub(/<key>CFBundleVersion<\/key>\s*<string>.*?<\/string>/,
        "<key>CFBundleVersion</key>\n\t<string>#{build_number}</string>")
    end

    def update_pbxproj_version(content)
      # For iOS project files
      version = release.release_version
      build_number = train.app.bump_build_number!(release_version: version)

      # Update MARKETING_VERSION
      content = content.gsub(/MARKETING_VERSION = .*?;/, "MARKETING_VERSION = #{version};")

      # Update CURRENT_PROJECT_VERSION
      content.gsub(/CURRENT_PROJECT_VERSION = .*?;/, "CURRENT_PROJECT_VERSION = #{build_number};")
    end

    memoize def version_bump_branch
      "version-bump-#{release_version}-#{Time.now.to_i}"
    end

    def hotfix_branch?
      hotfix? && new_hotfix_branch?
    end
  end
end
