class ThemesController < ApplicationController
  def update
    if Current.user.update(theme: params.require(:theme))
      redirect_back_or_to root_path, status: :see_other
    else
      redirect_back_or_to root_path, alert: "Unknown theme.", status: :see_other
    end
  end
end
