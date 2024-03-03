class V2::FormComponent < V2::BaseComponent
  renders_one :action
  renders_many :sections, ->(**args) { V2::Form::SectionComponent.new(form: @form, **args) }
  renders_many :advanced_sections, ->(**args) { V2::Form::SectionComponent.new(form: @form, **args) }

  def initialize(params)
    @params = params.merge(builder: EnhancedFormHelper::AuthzForm)
  end

  def set_form(form)
    @form = form
  end

  def free_form?
    @params[:free_form]
  end

  attr_reader :form
  alias_method :F, :form
end
