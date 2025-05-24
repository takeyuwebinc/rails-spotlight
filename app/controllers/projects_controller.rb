class ProjectsController < ApplicationController
  def index
    @projects = Project.published.ordered
  end
end
