# frozen_string_literal: true

module Admin
  module AdrManagement
    class ProjectsController < BaseController
      before_action :set_engagement
      before_action :set_project, only: %i[edit update destroy]

      def index
        @projects = @engagement.projects.order(:start_date)
      end

      def new
        @project = @engagement.projects.new
      end

      def edit
      end

      def create
        @project = @engagement.projects.new(project_params)

        if @project.save
          redirect_to admin_adr_management_engagement_path(@engagement), notice: "プロジェクトを作成しました。"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @project.update(project_params)
          redirect_to admin_adr_management_engagement_path(@engagement), notice: "プロジェクトを更新しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @project.destroy
          redirect_to admin_adr_management_engagement_path(@engagement), notice: "プロジェクトを削除しました。"
        else
          redirect_to admin_adr_management_engagement_path(@engagement),
            alert: "削除できません: #{@project.errors.full_messages.to_sentence}"
        end
      end

      private

      def set_engagement
        @engagement = ::AdrManagement::Engagement.find(params[:engagement_id])
      end

      def set_project
        @project = @engagement.projects.find(params[:id])
      end

      def project_params
        params.require(:adr_management_project).permit(:name, :start_date, :end_date)
      end
    end
  end
end
