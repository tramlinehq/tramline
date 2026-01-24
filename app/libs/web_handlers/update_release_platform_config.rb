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
    ActiveRecord::Base.transaction do
      new_params = transform_params(@original_params.deep_dup)
      config.update!(new_params)
    end

    errors.empty?
  rescue ActiveRecord::RecordInvalid => e
    copy_errors_from(e.record)
    false
  end

  private

  attr_reader :submission_types, :ci_actions, :release_platform

  def transform_params(params)
    mark_for_conditional_destruction(params)
    transform_workflow_data(params)
    transform_submission_data(params)
    transform_production_data(params)
    params
  end

  def mark_for_conditional_destruction(params)
    unless enabled?(params, :internal_release_enabled)
      if params[:internal_release_attributes].present?
        mark_for_destruction(params[:internal_release_attributes])
      end
      if params[:internal_workflow_attributes].present?
        mark_for_destruction(params[:internal_workflow_attributes])
      end
    end

    unless enabled?(params, :beta_release_submissions_enabled)
      params[:beta_release_attributes]&.dig(:submissions_attributes)&.each_value do |submission|
        mark_for_destruction(submission)
        mark_for_destruction(submission[:submission_external_attributes])
      end
    end

    unless enabled?(params, :production_release_enabled)
      if params[:production_release_attributes].present?
        mark_for_destruction(params[:production_release_attributes])
      end
    end
  end

  def transform_workflow_data(params)
    add_workflow_name(params[:internal_workflow_attributes])
    add_workflow_name(params[:release_candidate_workflow_attributes])
  end

  def transform_submission_data(params)
    transform_submissions(params[:internal_release_attributes])
    transform_submissions(params[:beta_release_attributes])
  end

  def transform_production_data(params)
    return unless release_platform.android?

    submission = params.dig(:production_release_attributes, :submissions_attributes, "0")
    return if submission.blank?

    transform_rollout_data(submission)
  end

  def transform_rollout_data(submission)
    if enabled?(submission, :rollout_enabled)
      submission[:rollout_stages] = submission[:rollout_stages].safe_csv_parse(coerce_float: true)
    else
      submission[:rollout_stages] = []
      submission[:finish_rollout_in_next_release] = false
      submission[:automatic_rollout] = false
      submission[:auto_start_rollout_after_submission] = false
    end
  end

  def transform_submissions(release_attrs)
    return if release_attrs.blank?

    release_attrs[:submissions_attributes]&.each_value do |submission|
      transform_single_submission(submission)
    end
  end

  def transform_single_submission(submission)
    variant = find_variant(submission[:integrable_id])
    return unless variant

    submission[:integrable_type] = variant[:type]
    ext_sub = find_external_submission(submission, variant)

    if ext_sub.present? && submission[:submission_external_attributes].present?
      submission[:submission_external_attributes][:name] = ext_sub[:name]
      submission[:submission_external_attributes][:internal] = ext_sub[:is_internal]
    end
  end

  def find_variant(integrable_id)
    submission_types[:variants].find { |v| v[:id] == integrable_id }
  end

  def find_external_submission(submission, variant)
    return nil if variant.blank?
    identifier = submission.dig(:submission_external_attributes, :identifier)
    return nil unless identifier

    submission_type = submission[:submission_type].to_s
    matching_type = variant[:submissions].find { |t| t[:type].to_s == submission_type }
    matching_type&.dig(:channels)&.find { |c| c[:id].to_s == identifier }
  end

  def add_workflow_name(workflow_attrs)
    return if workflow_attrs.blank?
    return if workflow_attrs[:identifier].blank?

    workflow_attrs[:name] = ci_actions.find { |a| a[:id] == workflow_attrs[:identifier] }&.dig(:name)
  end

  def enabled?(params, key)
    ActiveModel::Type::Boolean.new.cast(params[key])
  end

  def mark_for_destruction(attrs)
    attrs[:_destroy] = "1" if attrs.present?
  end

  def copy_errors_from(record)
    record.errors.full_messages.each do |msg|
      errors.add(:base, msg) unless errors.messages_for(:base).include?(msg)
    end
  end
end
