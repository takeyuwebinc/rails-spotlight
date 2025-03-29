module ApplicationHelper
  def home?
    params[:controller] == "home" && params[:action] == "index"
  end
end
