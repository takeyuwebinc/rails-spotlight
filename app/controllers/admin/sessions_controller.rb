# frozen_string_literal: true

module Admin
  class SessionsController < ApplicationController
    include AdminAuthenticatable

    layout "admin"

    # GET /admin/login
    def new
      # If already logged in, redirect to admin root
      if admin_signed_in?
        redirect_to admin_root_path
      end
    end

    # DELETE /admin/logout
    def destroy
      session.delete(:admin_email)
      session.delete(:admin_name)
      redirect_to admin_login_path, notice: "ログアウトしました"
    end
  end
end
