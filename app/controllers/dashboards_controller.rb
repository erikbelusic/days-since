class DashboardsController < ApplicationController
  def show
    @cards = Current.user.subscriptions.ordered.includes(:feed, :user).map do |subscription|
      [ subscription, DaysSinceCounter.new(subscription).result ]
    end
    @live = @cards.filter_map { |subscription, result| subscription if result.ongoing? }
  end
end
