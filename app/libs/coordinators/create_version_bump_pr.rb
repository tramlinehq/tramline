class Coordinators::CreateVersionBumpPR
  def self.call(release_platform_run)
    new(release_platform_run).call
  end

  def initialize(release_platform_run)
    @release_platform_run = release_platform_run
  end

  def call
    # Skip if PR already exists
    return if release_platform_run.has_pending_version_bump_pr?
    
    # Bump version internally first
    release_platform_run.bump_version!
    
    # Create PR for version bump
    create_version_bump_pr
  end

  private

  def create_version_bump_pr
    GitHub::Result.new do
      # Find build files in the repository
      build_files = find_build_files
      return if build_files.empty?

      # Create a version bump branch
      version_branch = "version-bump-#{release_platform_run.release_version}-#{Time.now.to_i}"
      train.create_branch!(release_branch, version_branch)

      # Update version in each build file on the version branch
      updated_files = []

      build_files.each do |file_path|
        file_result = update_version_in_file(version_branch, file_path)
        updated_files << file_path if file_result.ok?
      end

      if updated_files.any?
        # Create a PR to merge version changes into the release branch
        pr_title = "Bump version to #{release_platform_run.release_version}"
        pr_body = "Updates version numbers in build files for release #{release_platform_run.release_version}.\n\nUpdated files:\n- #{updated_files.join("\n- ")}"

        pr_result = train.vcs_provider.create_pr!(
          release_branch,
          version_branch,
          pr_title,
          pr_body
        )

        # Create a PullRequest record
        release.pull_requests.create!(
          number: pr_result[:number],
          title: pr_title,
          body: pr_body,
          state: PullRequest.states[:open],
          phase: PullRequest.phases[:ongoing],
          source: train.vcs_provider.provider_name.downcase,
          source_id: pr_result[:id].to_s,
          url: pr_result[:html_url],
          base_ref: release_branch,
          head_ref: version_branch,
          opened_at: Time.current
        )

        # Log the event
        release_platform_run.event_stamp!(
          reason: :version_bump_pr_created,
          kind: :notice,
          data: {
            release_version: release_platform_run.release_version,
            pr_number: pr_result[:number],
            pr_url: pr_result[:html_url]
          }
        )
      else
        release_platform_run.event_stamp!(
          reason: :version_bump_no_changes,
          kind: :notice,
          data: {release_version: release_platform_run.release_version}
        )
      end
    rescue => ex
      release_platform_run.event_stamp!(
        reason: :version_bump_failed,
        kind: :error,
        data: {error: ex.message}
      )
    end
  end

  def find_build_files
    # Similar to the find_build_files method in AlmostTrunk
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
        "Bump version to #{release_platform_run.release_version}",
        author_name: "Tramline",
        author_email: "tramline-bot@tramline.app"
      )
    else
      # Return success even if no changes were needed
      GitHub::Result.new { true }
    end
  end

  # Reuse the version update methods from AlmostTrunk
  def update_pubspec_version(content)
    # For Flutter pubspec.yaml files
    version_name = release_platform_run.release_version

    # Update version in pubspec.yaml
    content.gsub(/^version:\s*(\d+\.\d+\.\d+)(\+\d+)?/) do
      build_number = $2 || ""
      "version: #{version_name}#{build_number}"
    end
  end

  def update_gradle_version(content)
    # For Android build.gradle files
    version_name = release_platform_run.release_version
    version_code = train.app.bump_build_number!(release_version: version_name)

    # Update versionName
    content = content.gsub(/versionName\s+["'].*?["']/, "versionName \"#{version_name}\"")

    # Update versionCode
    content.gsub(/versionCode\s+\d+/, "versionCode #{version_code}")
  end

  def update_plist_version(content)
    # For iOS Info.plist files
    version = release_platform_run.release_version
    build_number = train.app.bump_build_number!(release_version: version)

    content = content.gsub(/<key>CFBundleShortVersionString<\/key>\s*<string>.*?<\/string>/,
      "<key>CFBundleShortVersionString</key>\n\t<string>#{version}</string>")

    content.gsub(/<key>CFBundleVersion<\/key>\s*<string>.*?<\/string>/,
      "<key>CFBundleVersion</key>\n\t<string>#{build_number}</string>")
  end

  def update_pbxproj_version(content)
    # For iOS project files
    version = release_platform_run.release_version
    build_number = train.app.bump_build_number!(release_version: version)

    # Update MARKETING_VERSION
    content = content.gsub(/MARKETING_VERSION = .*?;/, "MARKETING_VERSION = #{version};")

    # Update CURRENT_PROJECT_VERSION
    content.gsub(/CURRENT_PROJECT_VERSION = .*?;/, "CURRENT_PROJECT_VERSION = #{build_number};")
  end

  attr_reader :release_platform_run
  delegate :release, :train, :release_branch, to: :release_platform_run
end 
