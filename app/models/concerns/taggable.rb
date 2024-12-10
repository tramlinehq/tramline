module Taggable
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
    return [base_tag_name, "-", sha].join if currently.end_with?(base_tag_name)
    [base_tag_name, "-", sha, "-", Time.now.to_i].join
  end
end
