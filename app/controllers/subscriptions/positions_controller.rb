class Subscriptions::PositionsController < ApplicationController
  def update
    subscription = Current.user.subscriptions.find(params[:subscription_id])
    subscription.move_to(params.require(:position).to_i)
    head :no_content
  end
end
