class Accounts::AppsController < ApplicationController
  before_action :set_app, only: %i[show index]

  def new
    @app = current_organization.apps.new
  end

  def create
    @app = current_organization.apps.new(app_params)

    respond_to do |format|
      if @app.save
        format.html { redirect_to accounts_organization_app_path(current_organization, @app), notice: "App was successfully created." }
        format.json { render :show, status: :created, location: @app }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @app.errors, status: :unprocessable_entity }
      end
    end
  end

  def show
  end

  def index
  end

  private

  def set_app
    @app = current_organization.apps.friendly.find(params[:id])
  end

  def app_params
    params.require(:app).permit(:name, :description, :bundle_identifier)
  end
end
