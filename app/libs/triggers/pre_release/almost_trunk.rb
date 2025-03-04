class Triggers::PreRelease
  class AlmostTrunk
    def self.call(release, release_branch)
      new(release, release_branch).call
    end

    def initialize(release, release_branch)
      @release = release
      @release_branch = release_branch
    end

    def call
      bump_version if should_bump_version?
      create_branch
    end

    private

    attr_reader :release, :release_branch
    delegate :train, :hotfix?, :new_hotfix_branch?, to: :release
    delegate :working_branch, to: :train
    delegate :logger, to: Rails

    def create_branch
      GitHub::Result.new do
        source = source_ref
        train.create_branch!(source[:ref], release_branch, source_type: source[:type]).then do |value|
          stamp_data = {working_branch: source[:ref], release_branch:}
          release.event_stamp_now!(reason: :release_branch_created, kind: :success, data: stamp_data)
          GitHub::Result.new { value }
        end
      rescue Installations::Error => ex
        raise unless ex.reason == :tag_reference_already_exists
        logger.debug { "Pre-release branch already exists: #{release_branch}" }
      end
    end

    def hotfix_branch?
      hotfix? && new_hotfix_branch?
    end

    def source_ref
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
    end

    def should_bump_version?
      train.version_bump_enabled?
    end

    def bump_version
      GitHub::Result.new do
        # Use configured build files or fall back to finding them
        build_files = if train.version_bump_file_paths.present?
          train.version_bump_file_paths.split(",").map(&:strip)
        else
          find_build_files
        end

        return if build_files.empty?

        # Create a version bump branch
        version_branch = "version-bump-#{release.release_version}-#{Time.now.to_i}"
        train.create_branch!(release_branch, version_branch)

        # Update version in each build file on the version branch
        updated_files = []

        build_files.each do |file_path|
          file_result = update_version_in_file(version_branch, file_path)
          updated_files << file_path if file_result.ok?
        end

        if updated_files.any?
          # Create a PR to merge version changes into the release branch
          pr_title = "Bump version to #{release.release_version}"
          pr_body = "Updates version numbers in build files for release #{release.release_version}.\n\nUpdated files:\n- #{updated_files.join("\n- ")}"

          pr_result = train.vcs_provider.create_pr!(
            release_branch,
            version_branch,
            pr_title,
            pr_body
          )

          pr_number = pr_result[:number]
          pr_url = pr_result[:html_url]

          # PR created but needs manual merge
          release.event_stamp_now!(
            reason: :version_bump_pr_created,
            kind: :notice,
            data: {
              release_version: release.release_version,
              pr_number: pr_number,
              pr_url: pr_url,
              auto_merged: false
            }
          )
        else
          release.event_stamp_now!(
            reason: :version_bump_no_changes,
            kind: :notice,
            data: {release_version: release.release_version}
          )
        end
      rescue => ex
        logger.error { "Failed to bump version: #{ex.message}" }
        release.event_stamp_now!(
          reason: :version_bump_failed,
          kind: :error,
          data: {error: ex.message}
        )
      end
    end

    def find_build_files
      files = []

      # Check for Flutter pubspec.yaml
      pubspec_result = train.vcs_provider.get_file_content(release_branch, "pubspec.yaml")
      files << "pubspec.yaml" if pubspec_result.ok?

      if train.app.android?
        # Common Android build files
        android_files = [
          "android/app/build.gradle",
          "android/build.gradle",
          "app/build.gradle"
        ]

        android_files.each do |file|
          result = train.vcs_provider.get_file_content(release_branch, file)
          files << file if result.ok?
        end
      elsif train.app.ios?
        # Common iOS build files
        ios_files = [
          "ios/App/Info.plist",
          "ios/App/Project.pbxproj"
        ]

        ios_files.each do |file|
          result = train.vcs_provider.get_file_content(release_branch, file)
          files << file if result.ok?
        end
      end

      files
    end

    def update_version_in_file(branch, file_path)
      # Get the current file content
      content_result = train.vcs_provider.get_file_content(branch, file_path)
      return content_result unless content_result.ok?

      # Safely extract content with error handling
      content = content_result.value!

      # Update version based on file type
      updated_content = if file_path.end_with?(".gradle")
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
          "Bump version to #{release.release_version}",
          author_name: "Tramline",
          author_email: "tramline-bot@tramline.app"
        )
      else
        # Return success even if no changes were needed
        GitHub::Result.new { true }
      end
    end

    def update_pubspec_version(content)
      # For Flutter pubspec.yaml files
      version_name = release.release_version

      # Update version in pubspec.yaml
      # The version line typically looks like: version: 1.2.3+45
      # We want to update the semantic version part (1.2.3) but keep the build number (+45) if present
      content.gsub(/^version:\s*(\d+\.\d+\.\d+)(\+\d+)?/) do
        build_number = $2 || ""
        "version: #{version_name}#{build_number}"
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
  end
end
