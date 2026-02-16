require 'rails_helper'

RSpec.describe "Services", type: :request do
  describe "GET /services" do
    before { get services_path }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      expect(response.body).to include("Services")
    end

    it "displays outsourcing service" do
      expect(response.body).to include("受託開発")
    end

    it "displays technical advisor service" do
      expect(response.body).to include("技術顧問")
    end

    it "includes link to outsourcing detail page" do
      expect(response.body).to include("/services/outsourcing")
    end

    it "includes link to technical advisor detail page" do
      expect(response.body).to include("/services/technical_advisor")
    end

    it "includes contact form CTA" do
      expect(response.body).to include("https://forms.gle/scwNEGrT196rFnD9A")
    end
  end

  describe "GET /services/outsourcing" do
    before { get services_outsourcing_path }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      expect(response.body).to include("受託開発")
    end

    it "displays service content" do
      expect(response.body).to include("新規Webサービス開発")
      expect(response.body).to include("保守開発")
      expect(response.body).to include("システムリプレース")
    end

    it "displays contract types" do
      expect(response.body).to include("準委任契約")
      expect(response.body).to include("請負契約")
    end

    it "includes back link to services" do
      expect(response.body).to include("/services")
    end

    it "includes contact form CTA" do
      expect(response.body).to include("https://forms.gle/scwNEGrT196rFnD9A")
    end
  end

  describe "GET /services/technical_advisor" do
    before { get services_technical_advisor_path }

    it "returns http success" do
      expect(response).to have_http_status(:success)
    end

    it "displays page title" do
      expect(response.body).to include("技術顧問")
    end

    it "displays service content" do
      expect(response.body).to include("設計・コードレビュー")
      expect(response.body).to include("バージョンアップ支援")
      expect(response.body).to include("技術相談")
    end

    it "displays target customers" do
      expect(response.body).to include("こんなお客様に")
    end

    it "includes back link to services" do
      expect(response.body).to include("/services")
    end

    it "includes contact form CTA" do
      expect(response.body).to include("https://forms.gle/scwNEGrT196rFnD9A")
    end
  end
end
