# frozen_string_literal: true

module Oauth
  class SessionsController < ApplicationController
    layout "oauth"

    # GET /oauth/login
    def new
      # Store the authorization params to resume after authentication
      if params[:return_to].present?
        session[:oauth_return_to] = params[:return_to]
      end

      # If already logged in for OAuth, redirect back to authorization
      if session[:oauth_email].present?
        redirect_to_authorization
      end
    end

    # DELETE /oauth/logout
    def destroy
      session.delete(:oauth_email)
      session.delete(:oauth_name)
      redirect_to root_path, notice: "ログアウトしました"
    end

    private

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
