require 'rails_helper'

RSpec.describe "Legacy URL Redirects", type: :request do
  describe "GET /recruit" do
    it "redirects to root path with 301 status" do
      get "/recruit"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /jobs/*" do
    it "redirects /jobs to root path with 301 status" do
      get "/jobs"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(root_path)
    end

    it "redirects /jobs/software-engineer to root path with 301 status" do
      get "/jobs/software-engineer"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(root_path)
    end

    it "redirects /jobs/category/backend to root path with 301 status" do
      get "/jobs/category/backend"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /aboutus" do
    it "redirects to about path with 301 status" do
      get "/aboutus"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(about_path)
    end
  end

  describe "GET /company" do
    it "redirects to about path with 301 status" do
      get "/company"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(about_path)
    end
  end

  describe "GET /services/*" do
    it "redirects /services to projects path with 301 status" do
      get "/services"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(projects_path)
    end

    it "redirects /services/web-development to projects path with 301 status" do
      get "/services/web-development"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(projects_path)
    end

    it "redirects /services/consulting/rails to projects path with 301 status" do
      get "/services/consulting/rails"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(projects_path)
    end
  end

  describe "GET /works/*" do
    it "redirects /works to projects path with 301 status" do
      get "/works"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(projects_path)
    end

    it "redirects /works/portfolio to projects path with 301 status" do
      get "/works/portfolio"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(projects_path)
    end

    it "redirects /works/client/project-name to projects path with 301 status" do
      get "/works/client/project-name"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(projects_path)
    end
  end

  describe "GET /announcements/*" do
    it "redirects /announcements to root path with 301 status" do
      get "/announcements"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(root_path)
    end

    it "redirects /announcements/news to root path with 301 status" do
      get "/announcements/news"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(root_path)
    end

    it "redirects /announcements/2024/update to root path with 301 status" do
      get "/announcements/2024/update"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(root_path)
    end
  end

  describe "GET /contacts" do
    it "redirects to about path with 301 status" do
      get "/contacts"
      expect(response).to have_http_status(301)
      expect(response).to redirect_to(about_path)
    end
  end
end
