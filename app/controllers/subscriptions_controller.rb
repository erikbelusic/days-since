class SubscriptionsController < ApplicationController
  before_action :set_subscription, only: %i[ edit update destroy ]

  def new
    @form = SubscriptionForm.new
  end

  def create
    @form = SubscriptionForm.new(form_params.merge(user: Current.user))

    if @form.save
      redirect_to root_path, notice: "Added #{@form.subscription.name}."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @subscription.update(subscription_params)
      redirect_to root_path, notice: "Saved #{@subscription.name}."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @subscription.destroy!
    redirect_to root_path, notice: "Removed #{@subscription.name}.", status: :see_other
  end

  private
    def set_subscription
      @subscription = Current.user.subscriptions.find(params[:id])
    end

    def form_params
      params.expect(subscription_form: [ :url, :provider, :display_name ])
    end

    def subscription_params
      params.expect(subscription: [ :display_name, :min_severity ])
    end
end
