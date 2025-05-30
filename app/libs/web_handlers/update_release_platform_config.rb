# TODO: ensure the maps are consistently mutated or copied
# TODO: write tests for this service
class WebHandlers::UpdateReleasePlatformConfig
  using RefinedString

  def initialize(config, params, submission_types, ci_actions, release_platform)
    @config = config
    @original_params = params.deep_dup
    @submission_types = submission_types
    @ci_actions = ci_actions
    @release_platform = release_platform
    @processed_params = nil
    @internal_submission_order_map = {}
    @beta_submission_order_map = {}
    @internal_submissions_relation = config.internal_release&.submissions
    @beta_submissions_relation = config.beta_release&.submissions
    @errors = ActiveModel::Errors.new(self)
  end

  attr_reader :config, :errors

  def call
    self.processed_params = original_params

    # @config.errors.merge!(service.errors) # Uncomment if form re-renders and needs errors
    ActiveRecord::Base.transaction do
      params =
        processed_params
          .then { handle_conditional_destruction(_1) }
          .then { enrich_workflow_data(_1) }
          .then { enrich_submission_data(_1) }
          .then { enrich_production_data(_1) }

      config.update!(params)
    end
    errors.empty?
  rescue ActiveRecord::RecordInvalid => e
    copy_errors_from(e.record)
    false
  end

  private

  attr_reader :original_params, :submission_types, :ci_actions, :release_platform
  attr_accessor :processed_params, :internal_submission_order_map, :beta_submission_order_map

  def handle_conditional_destruction(processed_params)
    internal_enabled = original_params[:internal_release_enabled] == "true"
    beta_enabled = original_params[:beta_release_submissions_enabled] == "true"
    prod_enabled = original_params[:production_release_enabled] == "true"

    if !internal_enabled && processed_params[:internal_release_attributes].present?
      set_destroy!(processed_params[:internal_release_attributes])
      set_destroy!(processed_params[:internal_workflow_attributes])
    end

    if !beta_enabled && processed_params[:beta_release_attributes].present?
      processed_params[:beta_release_attributes][:submissions_attributes]&.each do |_, submission|
        set_destroy!(submission)
        set_destroy!(submission[:submission_external_attributes]) if submission[:submission_external_attributes]
      end
    end

    if !prod_enabled && processed_params[:production_release_attributes].present?
      set_destroy!(processed_params[:production_release_attributes])
    end

    processed_params
  end

  def enrich_workflow_data(processed_params)
    update_workflow_name(processed_params[:internal_workflow_attributes])
    update_workflow_name(processed_params[:release_candidate_workflow_attributes])
    processed_params
  end

  def enrich_submission_data(processed_params)
    update_submissions(processed_params[:internal_release_attributes])
    update_submissions(processed_params[:beta_release_attributes])

    reorder_submissions(@internal_submissions_relation&.reload, processed_params[:internal_release_attributes])
    reorder_submissions(@beta_submissions_relation&.reload, processed_params[:beta_release_attributes])

    processed_params
  end

  def enrich_production_data(processed_params)
    prod_attrs = processed_params[:production_release_attributes]

    if release_platform.android? && prod_attrs.present?
      submission_attrs = prod_attrs[:submissions_attributes]["0"]

      if submission_attrs.present? && submission_attrs[:rollout_enabled] == "true"
        submission_attrs[:rollout_stages] = submission_attrs[:rollout_stages].safe_csv_parse(coerce_float: true)
      else
        submission_attrs[:rollout_stages] = []
        submission_attrs[:finish_rollout_in_next_release] = false
      end
    end

    processed_params
  end

  def update_submissions(release_attributes)
    return if release_attributes.blank?

    release_attributes[:submissions_attributes]&.each do |_, submission|
      variant = submission_types[:variants].find { |v| v[:id] == submission[:integrable_id] }
      submission[:integrable_type] = variant[:type]

      ext_sub = find_submission(submission, variant)
      if ext_sub.present? && submission[:submission_external_attributes].present?
        submission[:submission_external_attributes][:name] = ext_sub[:name]
        submission[:submission_external_attributes][:internal] = ext_sub[:is_internal]
      end
    end
  end

  def update_workflow_name(workflow_attributes)
    if workflow_attributes&.dig(:identifier).present?
      workflow_attributes[:name] = find_workflow_name(workflow_attributes[:identifier])
    end
  end

  def reorder_submissions(existing_submissions_relation, release_attributes)
    return if existing_submissions_relation.blank? || release_attributes.blank?

    # create a copy of the submissions attributes to allow sorting by number
    sorted_submissions =
      release_attributes[:submissions_attributes]
        .to_h
        .reject { |_, attrs| attrs["_destroy"] == "1" }
        .sort_by { |_, attrs| attrs["number"].to_i }

    # set all existing submissions to temporary negative numbers to avoid conflicts
    existing_submissions = existing_submissions_relation.index_by(&:id)
    existing_submissions.each do |_, submission|
      submission.update!(number: -submission.number)
    end

    sorted_submissions.each_with_index do |(id, submission_attrs), index|
      new_number = index + 1

      # update the original release attributes
      release_attributes[:submissions_attributes][id]["number"] = new_number.to_s

      # update the existing submissions in the DB
      if submission_attrs["id"].present? && (existing_submission = existing_submissions[submission_attrs["id"].to_i])
        existing_submission.update!(number: new_number)
      end
    end

    release_attributes
  end

  def find_workflow_name(identifier)
    ci_actions.find { |action| action[:id] == identifier }&.dig(:name)
  end

  def find_submission(submission, variant)
    return nil if variant.blank?
    identifier = submission.dig(:submission_external_attributes, :identifier)
    return nil unless identifier

    variant[:submissions].find { |type| type[:type].to_s == submission[:submission_type].to_s }
      &.then { |sub| sub.dig(:channels) }
      &.then { |channels| channels.find { |channel| channel[:id].to_s == identifier } }
  end

  def set_destroy!(param)
    param[:_destroy] = "1" if param.present?
  end

  def copy_errors_from(record)
    record.errors.full_messages.each do |msg|
      errors.add(:base, msg) unless errors.messages_for(:base).include?(msg)
    end
  end
end
