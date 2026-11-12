class SubscriptionsController < ApplicationController
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

  private
    def form_params
      params.expect(subscription_form: [ :url, :provider, :display_name ])
    end
end
