module Taggable
  # recursively attempt to create a release tag until a unique one gets created
  # it *can* get expensive in the worst-case scenario, so ideally invoke this in a bg job
  def create_tag!(commitish, input_tag_name = base_tag_name)
    return if tag_name.present?
    train.create_tag!(input_tag_name, commitish)
    update!(tag_name: input_tag_name)
    event_stamp!(reason: :tag_created, kind: :notice, data: {tag: input_tag_name})
  rescue Installations::Error => ex
    raise unless ex.reason == :tag_reference_already_exists
    create_tag!(commitish, unique_tag_name(input_tag_name, commitish))
  end

  # recursively attempt to create a vcs release until a unique one gets created
  # it *can* get expensive in the worst-case scenario, so ideally invoke this in a bg job
  def create_vcs_release!(commitish, release_diff, input_tag_name = base_tag_name)
    return if tag_name.present?
    train.create_vcs_release!(commitish, input_tag_name, previous_tag_name, release_diff)
    update!(tag_name: input_tag_name)
    event_stamp!(reason: :vcs_release_created, kind: :notice, data: {provider: train.vcs_provider.display, tag: input_tag_name})
  rescue Installations::Error => ex
    raise unless [:tag_reference_already_exists, :tagged_release_already_exists].include?(ex.reason)
    create_vcs_release!(commitish, release_diff, unique_tag_name(input_tag_name, commitish))
  end

  # returns a sticky but unique tag name
  # tries to optimize for the most readable tag name
  #
  # for eg.
  # v1.0.0-android-0cf2849
  # v1.0.0-android-0cf2849-1691092406
  # v1.0.0-android-0cf2849-1691092492
  # ...and so on
  #
  # note: avoids appending increasing numbers to avoid keeping state
  # note: relies on a 'base_tag_name' method
  def unique_tag_name(currently, sha)
    short_sha = sha[0, 7]
    return [base_tag_name, "-", short_sha].join if currently.end_with?(base_tag_name)
    [base_tag_name, "-", short_sha, "-", Time.now.to_i].join
  end

  def tag_url
    train.vcs_provider&.tag_url(tag_name)
  end
end
