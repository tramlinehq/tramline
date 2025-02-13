# frozen_string_literal: true

class ReleaseHistoryComponent < BaseComponent
  include Memery
  include Pagy::Frontend

  attr_reader :train, :previous_releases, :paginator

  def initialize(train:, previous_releases:, paginator:)
    @train = train
    @previous_releases = previous_releases
    @paginator = paginator
  end

  def release_table_columns
    if reldex_defined?
      ["", "release", "branch", "reldex", "dates", ""]
    else
      ["", "release", "branch", "dates", ""]
    end
  end

  def reldex_defined?
    train.release_index.present?
  end
end
