class DashboardLayoutsController < ApplicationController
  def update
    Current.user.update!(dashboard_layout: params.require(:layout))
    redirect_to root_path, status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to root_path, alert: "Unknown dashboard layout.", status: :see_other
  end
end
