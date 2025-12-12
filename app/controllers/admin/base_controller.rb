# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    layout "admin"

    http_basic_authenticate_with(
      name: Rails.application.credentials.dig(:admin, :username) || "admin",
      password: Rails.application.credentials.dig(:admin, :password) || "password"
    )
  end
end
