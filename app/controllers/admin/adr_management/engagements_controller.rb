# frozen_string_literal: true

module Admin
  module AdrManagement
    class EngagementsController < BaseController
      before_action :set_engagement, only: %i[show edit update destroy]

      def index
        @engagements = ::AdrManagement::Engagement.includes(client: :shared_client).order(:code)
      end

      def show
        @projects = @engagement.projects.order(:start_date)
        @adrs = @engagement.adrs.order(number: :desc)
      end

      def new
        @engagement = ::AdrManagement::Engagement.new(client_id: params[:client_id])
      end

      def edit
      end

      def create
        @engagement = ::AdrManagement::Engagement.new(engagement_params)

        if @engagement.save
          redirect_to admin_adr_management_engagement_path(@engagement), notice: "案件を作成しました。"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @engagement.update(engagement_params)
          redirect_to admin_adr_management_engagement_path(@engagement), notice: "案件を更新しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @engagement.destroy
          redirect_to admin_adr_management_engagements_path, notice: "案件を削除しました。"
        else
          redirect_to admin_adr_management_engagement_path(@engagement),
            alert: "削除できません: #{@engagement.errors.full_messages.to_sentence}"
        end
      end

      private

      def set_engagement
        @engagement = ::AdrManagement::Engagement.find(params[:id])
      end

      def engagement_params
        params.require(:adr_management_engagement).permit(:code, :name, :description, :client_id)
      end
    end
  end
end
