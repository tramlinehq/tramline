class Triggers::VersionBump
  include Memery

  VersionBumpError = Class.new(Triggers::Errors)
  DEFAULT_PR_AUTHOR_NAME = "Tramline"
  DEFAULT_PR_AUTHOR_EMAIL = "tramline-bot@tramline.app"

  def self.call(release)
    return unless release.train.version_bump_enabled?
    new(release).call
  end

  def initialize(release)
    @release = release
    @train = release.train
    raise ArgumentError, "Version bumping is not enabled" unless @train.version_bump_enabled?
    @strategy = @train.version_bump_strategy.to_sym
  end

  def call
    return GitHub::Result.new if version_bump_file_paths.empty?
    create_branch.then { update_files_and_create_pr }
  end

  attr_reader :release, :train, :strategy
  delegate :working_branch, :version_bump_file_paths, :version_bump_branch_prefix, to: :train
  delegate :logger, to: Rails

  def create_branch
    Triggers::Branch.call(release,
      working_branch,
      version_bump_branch,
      :branch,
      {version_bump_branch:, release_version:},
      :version_bump_branch_created)
  end

  def update_files_and_create_pr
    # update version in each build file on the version branch
    # each file will create its own commit so that its easy to revert changes
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

    # create (and merge) PR
    Triggers::PullRequest.create_and_merge!(**pr_attributes(pr_title, pr_body(updated_files)))
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
        content # no change for unknown file types
      end

    # write it back if changed
    if content != updated_content
      train.vcs_provider.update_file!(
        branch,
        file_path,
        updated_content,
        "Bump version to #{release_version} in #{file_path}",
        author_name: DEFAULT_PR_AUTHOR_NAME,
        author_email: DEFAULT_PR_AUTHOR_EMAIL
      )
    end
  rescue Installations::Error
    raise VersionBumpError, "Failed to update #{file_path} with version #{release_version}"
  end

  # The version line typically looks like: version: 1.2.3+45 (+45 is optional)
  # We want to update the semantic version part (1.2.3) but keep the build number (+45) if present
  # Note that – version: "1.0.0+1" is also valid, since quotes around strings in YAML are optional
  def update_pubspec_version(content)
    content.gsub(/^version:\s*["']?(?<version>\d+\.\d+\.\d+)(?<build>\+\d+)?["']?/) do
      build_number = Regexp.last_match[:build] || ""
      "version: #{release_version}#{build_number}"
    end
  end

  # The version line typically looks like: versionName "1.0.0"
  # The quotations are mandatory and the spaces between the keyword and the string are also mandatory
  # If there is a variable that succeeds it, we ignore and don't change anything
  # --
  # We also support versionName being updated in a groovy dictionary (https://groovy.code-maven.com/groovy-map)
  # The line would be typically like: "versionName": "1.0.0" as a part of a larger dict or associative array
  def update_gradle_version(content)
    content
      .then { |c| c.gsub(/versionName\s+"[^"]*"/, "versionName \"#{release_version}\"") } # direct declaration
      .then { |c| c.gsub(/("versionName"\s*:\s*)"[^"]*"/, "\\1\"#{release_version}\"") } # dictionary declaration
  end

  # The version line typically looks like: versionName = "1.0.0"
  # The quotations are mandatory and the spaces between the variable and the string are optional
  # If instead of a string we have a variable, we ignore and don't change anything
  def update_gradle_kts_version(content)
    content.gsub(/versionName\s*=\s*"[^"]*"/, "versionName = \"#{release_version}\"") do
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
    [version_bump_branch_prefix, "version-bump", release_version, release.slug].compact_blank.join("-")
  end

  memoize def release_version
    case strategy
    when :current_version_before_release_branch
      release.release_version
    when :next_version_after_release_branch
      release.next_version
    end
  end

  def pr_title
    case strategy
    when :current_version_before_release_branch
      "Bump version to #{release_version}"
    when :next_version_after_release_branch
      "Update next version to #{release_version}"
    end
  end

  def pr_body(updated_files)
    case strategy
    when :current_version_before_release_branch
      <<~BODY
        🎉 A new release #{release_version} has kicked off!

        This PR updates the version number in `#{updated_files.join(", ")}` to prepare for our #{release_version} release.

        All aboard the release train!
      BODY
    when :next_version_after_release_branch
      <<~BODY
        This PR updates the next version number in `#{updated_files.join(", ")}` to prepare for future releases.

        All aboard the release train!
      BODY
    end
  end

  def pr_attributes(title, description)
    base = {release:, title:, description:, error_result_on_auto_merge: true}
    new =
      case strategy
      when :current_version_before_release_branch
        {
          new_pull_request_attrs: {phase: :pre_release, kind: :version_bump, release_id: release.id, state: :open},
          existing_pr: release.pull_requests.pre_release.version_bump_type.open.first,
          to_branch_ref: working_branch,
          from_branch_ref: version_bump_branch
        }
      when :next_version_after_release_branch
        {
          new_pull_request_attrs: {phase: :mid_release, kind: :version_bump, release_id: release.id, state: :open},
          existing_pr: release.pull_requests.mid_release.version_bump_type.open.first,
          to_branch_ref: working_branch,
          from_branch_ref: version_bump_branch
        }
      else
        {}
      end

    base.merge(new)
  end
end
