module ExternalReleaseHelper
  def external_release_status_timestamp(external_release)
    if external_release.released_at
      "Released #{ago_in_words(external_release.released_at)}"
    elsif external_release.reviewed_at
      "Reviewed #{ago_in_words(external_release.reviewed_at)}"
    else
      "Changed #{ago_in_words(external_release.updated_at)}"
    end
  end
end
