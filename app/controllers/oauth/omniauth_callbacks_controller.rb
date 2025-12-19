# frozen_string_literal: true

module Oauth
  class OmniauthCallbacksController < ApplicationController
    ALLOWED_DOMAIN = "takeyuweb.co.jp"

    layout "oauth"

    # GET /oauth/auth/oauth_google/callback
    def oauth_google
      auth = request.env["omniauth.auth"]

      if auth.nil?
        redirect_to new_oauth_session_path, alert: "認証情報を取得できませんでした"
        return
      end

      email = auth.info.email
      name = auth.info.name

      unless valid_domain?(email)
        Rails.logger.warn("OAuth login rejected for email: #{email}")
        redirect_to new_oauth_session_path, alert: "このアカウントではログインできません。@#{ALLOWED_DOMAIN} のアカウントをお使いください。"
        return
      end

      # Store user info in session for Doorkeeper
      session[:oauth_email] = email
      session[:oauth_name] = name

      # Redirect back to the OAuth authorization flow
      redirect_to_authorization
    end

    # GET /oauth/auth/failure
    def failure
      redirect_to new_oauth_session_path, alert: "Googleとの認証に失敗しました。再度お試しください。"
    end

    private

    def valid_domain?(email)
      return false if email.blank?

      domain = email.split("@").last
      domain == ALLOWED_DOMAIN
    end

    def redirect_to_authorization
      return_to = session.delete(:oauth_return_to)
      if return_to.present?
        redirect_to return_to, allow_other_host: false
      else
        redirect_to root_path
      end
    end
  end
end
