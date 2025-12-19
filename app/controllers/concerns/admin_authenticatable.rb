# frozen_string_literal: true

module AdminAuthenticatable
  extend ActiveSupport::Concern

  included do
    helper_method :admin_signed_in?, :current_admin_email, :current_admin_name
  end

  private

  def admin_signed_in?
    session[:admin_email].present?
  end

  def current_admin_email
    session[:admin_email]
  end

  def current_admin_name
    session[:admin_name]
  end

  def authenticate_admin!
    return if admin_signed_in?

    redirect_to admin_login_path, alert: "ログインが必要です"
  end
end
