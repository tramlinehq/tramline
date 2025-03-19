class Triggers::VersionBump
  include Memery

  DEFAULT_PR_AUTHOR_NAME = "Tramline"
  DEFAULT_PR_AUTHOR_EMAIL = "tramline-bot@tramline.app"

  def self.call(release)
    new(release).call
  end

  def initialize(release)
    @release = release
  end

  def call
    create_branch.then { create_pr }
  end

  attr_reader :release
  delegate :train, :release_version, to: :release
  delegate :working_branch, :version_bump_file_paths, to: :train
  delegate :logger, to: Rails

  def create_branch
    Triggers::Branch.call(release,
      working_branch,
      version_bump_branch,
      :branch,
      {version_bump_branch:, release_version:},
      :version_bump_branch_created)
  end

  def create_pr
    return GitHub::Result.new if version_bump_file_paths.empty?

    # Update version in each build file on the version branch
    # Each file will create its own commit so that its easy to revert changes
    updated_files_result = GitHub::Result.new do
      updated_files = []
      version_bump_file_paths.each do |file_path|
        file_result = update_version_in_file(version_bump_branch, file_path)
        updated_files << file_path if file_result
      end
      updated_files
    end
    return updated_files_result unless updated_files_result.ok?
    updated_files = updated_files_result.value!
    if updated_files.empty?
      release.event_stamp_now!(reason: :version_bump_no_changes, kind: :notice, data: {release_version:})
      return GitHub::Result.new
    end

    # create PR
    pr_title = "Bump version to #{release_version}"
    pr_body = <<~BODY
      🎉 A new release #{release_version} has kicked off!

      This PR updates the version number in `#{updated_files.join(", ")}` to prepare for our #{release_version} release.

      All aboard the release train!
    BODY
    pr_result = Triggers::PullRequest.create_and_merge!(
      release: release,
      new_pull_request: release.pull_requests.version_bump.open.build,
      existing_pr: release.pull_requests.version_bump.open.first,
      to_branch_ref: working_branch,
      from_branch_ref: version_bump_branch,
      title: pr_title,
      description: pr_body,
      error_result_on_auto_merge: true
    )
    if pr_result.ok?
      release.event_stamp_now!(reason: :version_bump_pr_created, kind: :notice, data: {release_version:})
    else
      release.event_stamp_now!(reason: :version_bump_pr_failed, kind: :error, data: {error: pr_result.error})
    end
    pr_result
  end

  # The matchers will update all instances of matches in the file (can be more than 1)
  def update_version_in_file(branch, file_path)
    content = train.vcs_provider.get_file_content(branch, file_path)
    extension = File.extname(file_path)
    file_types = Train::ALLOWED_VERSION_BUMP_FILE_TYPES
    updated_content =
      case extension
      when file_types[:gradle] then update_gradle_version(content)
      when file_types[:kotlin_gradle] then update_gradle_kts_version(content)
      when file_types[:plist] then update_plist_version(content)
      when file_types[:pbxproj] then update_pbxproj_version(content)
      when file_types[:yaml] then update_pubspec_version(content)
      else
        # No change for unknown file types
        content
      end

    # Write it back if changed
    if content != updated_content
      train.vcs_provider.update_file(
        branch,
        file_path,
        updated_content,
        "Bump version to #{release_version} in #{file_path}",
        author_name: DEFAULT_PR_AUTHOR_NAME,
        author_email: DEFAULT_PR_AUTHOR_EMAIL
      )
    end
  end

  # The version line typically looks like: version: 1.2.3+45
  # We want to update the semantic version part (1.2.3) but keep the build number (+45) if present
  def update_pubspec_version(content)
    content.gsub(/^version:\s*(\d+\.\d+\.\d+)(\+\d+)?/) do
      build_number = $2 || ""
      "version: #{release_version}#{build_number}"
    end
  end

  def update_gradle_version(content)
    content.gsub(/versionName\s+(['"][^'"]*['"]|\w+)/, "versionName \"#{release_version}\"")
  end

  def update_gradle_kts_version(content)
    content.gsub(/versionName\s*=\s*(['"][^'"]*['"]|\w+)(?=\s*[^=]*$)/, "versionName = \"#{release_version}\"") do
      "#{match.split("=").first.strip} = #{new_value}"
    end
  end

  def update_plist_version(content)
    content.gsub(/<key>CFBundleShortVersionString<\/key>\s*<string>.*?<\/string>/,
      "<key>CFBundleShortVersionString</key>\n\t<string>#{release_version}</string>")
  end

  def update_pbxproj_version(content)
    content.gsub(/MARKETING_VERSION = .*?;/, "MARKETING_VERSION = #{release_version};")
  end

  memoize def version_bump_branch
    "version-bump-#{release_version}-#{release.slug}"
  end
end
