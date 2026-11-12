class SettingsController < ApplicationController
  before_action :set_user

  def edit
  end

  def update
    if @user.update(settings_params)
      redirect_to root_path, notice: "Settings saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_user
      @user = Current.user
    end

    def settings_params
      params.expect(user: [ :time_zone, :default_min_severity, :no_incident_display ])
    end
end
