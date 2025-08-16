class SlidesController < ApplicationController
  before_action :set_slide
  before_action :check_draft_access

  def show
    @current_page = params[:page]&.to_i || 1
    @slide_page = @slide.page_at(@current_page)

    if @slide_page.nil?
      redirect_to slide_path(@slide, page: 1)
      return
    end

    render layout: "slide"
  end

  private

  def set_slide
    @slide = Slide.find_by!(slug: params[:id])
  end

  def check_draft_access
    if @slide.draft? && !Rails.env.local?
      raise ActiveRecord::RecordNotFound
    end
  end
end
