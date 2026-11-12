class DashboardsController < ApplicationController
  def show
    @cards = Current.user.subscriptions.ordered.includes(:user, feed: { logo_attachment: :blob }).map do |subscription|
      [ subscription, DaysSinceCounter.new(subscription).result ]
    end
    @live = @cards.filter_map { |subscription, result| subscription if result.ongoing? }
  end
end
