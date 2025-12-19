# frozen_string_literal: true

module Admin
  class OmniauthCallbacksController < ApplicationController
    include AdminAuthenticatable

    ALLOWED_DOMAIN = "takeyuweb.co.jp"

    layout "admin"

    # GET /admin/auth/google_oauth2/callback
    def google_oauth2
      auth = request.env["omniauth.auth"]

      if auth.nil?
        redirect_to admin_login_path, alert: "認証情報を取得できませんでした"
        return
      end

      email = auth.info.email
      name = auth.info.name

      unless valid_domain?(email)
        Rails.logger.warn("Admin login rejected for email: #{email}")
        redirect_to admin_login_path, alert: "このアカウントではログインできません。@#{ALLOWED_DOMAIN} のアカウントをお使いください。"
        return
      end

      # Store user info in session
      session[:admin_email] = email
      session[:admin_name] = name

      redirect_to admin_root_path, notice: "ログインしました"
    end

    # GET /admin/auth/failure
    def failure
      redirect_to admin_login_path, alert: "Googleとの認証に失敗しました。再度お試しください。"
    end

    private

    def valid_domain?(email)
      return false if email.blank?

      domain = email.split("@").last
      domain == ALLOWED_DOMAIN
    end
  end
end
