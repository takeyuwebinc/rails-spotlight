class HomeController < ApplicationController
  def index
    @featured_projects = Project.published.limit(3)
    @availability = WorkHour::AvailabilityCalculator.new(months_ahead: 3).monthly_availability

    # Ruby on Rails受託開発に特化したSEOメタデータ
    @seo_title = "Ruby on Rails受託開発"
    @seo_description = "Ruby on Railsの受託開発・技術顧問。2006年からRails一筋のエンジニアが、新規開発・保守・技術相談まで一人で幅広くお引き受けします。"
    @seo_og_type = "website"
    @seo_canonical_url = root_url
  end

  def about
    @availability = WorkHour::AvailabilityCalculator.new(months_ahead: 3).monthly_availability
  end
end
