# TODO: ensure the maps are consistently mutated or copied
# TODO: write tests for this service
# TODO: list down scenarios this doesn't solve for
class WebHandlers::UpdateReleasePlatformConfig
  using RefinedString

  def initialize(config, params, submission_types, ci_actions, release_platform)
    @config = config
    @original_params = params.deep_dup
    @submission_types = submission_types
    @ci_actions = ci_actions
    @release_platform = release_platform
    @errors = ActiveModel::Errors.new(self)
  end

  attr_reader :config, :errors

  def call
    params = transform_params(@original_params.deep_dup)

    ActiveRecord::Base.transaction do
      config.update!(params)
    end

    errors.empty?
  rescue ActiveRecord::RecordInvalid => e
    copy_errors_from(e.record)
    false
  end

  private

  attr_reader :submission_types, :ci_actions, :release_platform

  def transform_params(params)
    params
      .then { |p| transform_conditional_destruction(p.deep_dup) }
      .then { |p| transform_workflow_data(p.deep_dup) }
      .then { |p| transform_submission_data(p.deep_dup) }
      .then { |p| transform_production_data(p.deep_dup) }
  end

  def transform_conditional_destruction(params)
    internal_enabled = params[:internal_release_enabled] == "true"
    beta_enabled = params[:beta_release_submissions_enabled] == "true"
    prod_enabled = params[:production_release_enabled] == "true"

    # if internal releases were shut off, remove all previous internal data
    if !internal_enabled && params[:internal_release_attributes].present?
      mark_for_destruction(params[:internal_release_attributes])
      mark_for_destruction(params[:internal_workflow_attributes])
    end

    # if beta releases were shut off, remove all previous beta data
    if !beta_enabled && params[:beta_release_attributes].present?
      params[:beta_release_attributes][:submissions_attributes]&.each do |_, submission|
        mark_for_destruction(submission)
        if submission[:submission_external_attributes]
          mark_for_destruction(submission[:submission_external_attributes])
        end
      end
    end

    # if prod release was shut off, remove all previous prod data
    if !prod_enabled && params[:production_release_attributes].present?
      mark_for_destruction(params[:production_release_attributes])
    end

    params
  end

  # assign workflow names based on identifiers from the form
  def transform_workflow_data(params)
    params[:internal_workflow_attributes] = add_workflow_name(params[:internal_workflow_attributes])
    params[:release_candidate_workflow_attributes] = add_workflow_name(params[:release_candidate_workflow_attributes])
    params
  end

  def transform_submission_data(params)
    params[:internal_release_attributes] = transform_submissions(params[:internal_release_attributes])
    params[:beta_release_attributes] = transform_submissions(params[:beta_release_attributes])

    params[:internal_release_attributes] = reorder_submissions(@config.internal_release&.submissions, params[:internal_release_attributes])
    params[:beta_release_attributes] = reorder_submissions(@config.beta_release&.submissions, params[:beta_release_attributes])
    params
  end

  def transform_production_data(params)
    return params unless release_platform.android? && params[:production_release_attributes].present?

    submission = params[:production_release_attributes][:submissions_attributes]&.fetch("0", nil)
    return params if submission.blank?

    params[:production_release_attributes][:submissions_attributes]["0"] = transform_rollout_data(submission.deep_dup)
    params
  end

  def transform_rollout_data(submission)
    if submission[:rollout_enabled] == "true"
      submission[:rollout_stages] = submission[:rollout_stages].safe_csv_parse(coerce_float: true)
    else
      submission[:rollout_stages] = []
      submission[:finish_rollout_in_next_release] = false
    end

    submission
  end

  def transform_submissions(release_attrs)
    return nil if release_attrs.blank?
    new_release_attrs = release_attrs.deep_dup

    new_release_attrs[:submissions_attributes]&.transform_values! do |submission|
      transform_single_submission(submission)
    end

    new_release_attrs
  end

  def transform_single_submission(submission)
    new_submission = submission.deep_dup
    variant = find_variant(submission[:integrable_id])
    return new_submission unless variant

    new_submission[:integrable_type] = variant[:type]
    ext_sub = find_external_submission(new_submission, variant)

    if ext_sub.present? && new_submission[:submission_external_attributes].present?
      new_submission[:submission_external_attributes] = {
        **new_submission[:submission_external_attributes],
        name: ext_sub[:name],
        internal: ext_sub[:is_internal]
      }
    end

    new_submission
  end

  def find_variant(integrable_id)
    submission_types[:variants].find { |v| v[:id] == integrable_id }
  end

  def find_external_submission(submission, variant)
    return nil if variant.blank?
    identifier = submission.dig(:submission_external_attributes, :identifier)
    return nil unless identifier

    variant[:submissions]
      .find { |type| type[:type].to_s == submission[:submission_type].to_s }
      &.then { |sub| sub.dig(:channels) }
      &.then { |channels| channels.find { |channel| channel[:id].to_s == identifier } }
  end

  def add_workflow_name(workflow_attrs)
    return workflow_attrs if workflow_attrs.blank?

    new_attrs = workflow_attrs.deep_dup
    if new_attrs[:identifier].present?
      new_attrs[:name] = ci_actions.find { |action| action[:id] == new_attrs[:identifier] }&.dig(:name)
    end
    new_attrs
  end

  def mark_for_destruction(attrs)
    attrs[:_destroy] = "1" if attrs.present?
  end

  def reorder_submissions(existing_submissions_relation, release_attrs)
    return release_attrs if existing_submissions_relation.blank? || release_attrs.blank?

    # Sort submissions by number
    sorted_submissions = release_attrs[:submissions_attributes]
      .to_h
      .reject { |_, attrs| attrs["_destroy"] == "1" }
      .sort_by { |_, attrs| attrs["number"].to_i }

    # Temporarily update existing submissions
    existing_submissions = existing_submissions_relation.index_by(&:id)
    existing_submissions.each { |_, sub| sub.update!(number: -sub.number) }

    # Create new attributes with updated numbers
    new_release_attrs = release_attrs.deep_dup
    sorted_submissions.each_with_index do |(id, submission_attrs), index|
      new_number = index + 1
      new_release_attrs[:submissions_attributes][id]["number"] = new_number.to_s

      if submission_attrs["id"].present?
        existing_sub = existing_submissions[submission_attrs["id"].to_i]
        existing_sub&.update!(number: new_number)
      end
    end

    new_release_attrs
  end

  def copy_errors_from(record)
    record.errors.full_messages.each do |msg|
      errors.add(:base, msg) unless errors.messages_for(:base).include?(msg)
    end
  end
end
