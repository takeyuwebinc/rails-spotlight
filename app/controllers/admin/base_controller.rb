# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include AdminAuthenticatable
    include ObservabilityUserContext

    layout "admin"

    before_action :authenticate_admin!
    before_action :tag_observability_user

    private

    def tag_observability_user
      return unless admin_signed_in?

      set_observability_user(
        id: current_admin_email,
        email: current_admin_email,
        name: current_admin_name
      )
    end
  end
end
