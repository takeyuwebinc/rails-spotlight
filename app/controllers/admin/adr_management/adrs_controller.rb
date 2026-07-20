# frozen_string_literal: true

module Admin
  module AdrManagement
    class AdrsController < BaseController
      before_action :set_adr, only: %i[show edit update destroy]

      def index
        @engagements = ::AdrManagement::Engagement.order(:code)
        @adrs = filtered_adrs
      end

      def show
        @revisions = @adr.revisions.recent_first
      end

      def new
        @adr = ::AdrManagement::Adr.new(engagement_id: params[:engagement_id], status: "accepted")
        load_form_context(@adr.engagement_id)
      end

      def edit
        load_form_context(@adr.engagement_id)
      end

      def create
        attrs = adr_params
        engagement = ::AdrManagement::Engagement.find_by(id: attrs[:engagement_id])

        unless engagement
          @adr = ::AdrManagement::Adr.new(attrs)
          @adr.errors.add(:engagement, :blank)
          load_form_context(nil)
          return render :new, status: :unprocessable_entity
        end

        result = ::AdrManagement::RegisterAdr.perform(
          engagement: engagement,
          attributes: attrs.except(:engagement_id).to_h,
          origin: web_origin,
          superseded_numbers: superseded_numbers_param
        )

        if result.success?
          redirect_to admin_adr_management_adr_path(result.data), notice: "ADR を登録しました。"
        else
          @adr = ::AdrManagement::Adr.new(attrs)
          @operation_errors = result.errors
          load_form_context(engagement.id)
          render :new, status: :unprocessable_entity
        end
      end

      def update
        engagement_changed, error = change_engagement_if_requested
        if error
          @operation_errors = error
          load_form_context(@adr.engagement_id)
          return render :edit, status: :unprocessable_entity
        end

        update_attrs = adr_params.except(:engagement_id).to_h
        # 案件を変更した場合、フォームのプロジェクト選択肢は変更前の案件の
        # ものであり移動先では無効なため反映しない（参照は解除済み）
        update_attrs.delete("project_id") if engagement_changed

        result = ::AdrManagement::UpdateAdr.perform(
          adr: @adr,
          attributes: update_attrs,
          origin: web_origin
        )

        if result.success?
          redirect_to admin_adr_management_adr_path(@adr), notice: "ADR を更新しました。"
        else
          @operation_errors = result.errors
          load_form_context(@adr.engagement_id)
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @adr.supersession_involved?
          return redirect_to admin_adr_management_adr_path(@adr),
            alert: "置換関係を持つ ADR は削除できません。"
        end

        if @adr.destroy
          redirect_to admin_adr_management_adrs_path, notice: "ADR を削除しました。"
        else
          redirect_to admin_adr_management_adr_path(@adr),
            alert: "削除できません: #{@adr.errors.full_messages.to_sentence}"
        end
      end

      private

      def set_adr
        @adr = ::AdrManagement::Adr.find(params[:id])
      end

      def filtered_adrs
        adrs = ::AdrManagement::Adr.includes(:engagement).order(decided_on: :desc, id: :desc)
        adrs = adrs.where(engagement_id: params[:engagement_id]) if params[:engagement_id].present?
        adrs = adrs.where(status: params[:status]) if params[:status].present?
        if params[:keyword].present?
          pattern = "%#{::AdrManagement::Adr.sanitize_sql_like(params[:keyword])}%"
          adrs = adrs.where(
            [ "title", "context", "decision", "consequences", "alternatives" ]
              .map { |column| "#{column} LIKE :pattern" }.join(" OR "),
            pattern: pattern
          )
        end
        adrs
      end

      # フォームの選択肢。プロジェクトと置換対象は同一案件のものに限られるため、
      # 案件が確定している場合のみ選択肢を出す
      def load_form_context(engagement_id)
        @engagements = ::AdrManagement::Engagement.order(:code)
        @engagement = ::AdrManagement::Engagement.find_by(id: engagement_id)
        @projects = @engagement ? @engagement.projects.order(:start_date) : ::AdrManagement::Project.none
        @supersession_candidates = @engagement ? @engagement.adrs.accepted.order(:number) : ::AdrManagement::Adr.none
      end

      # 戻り値: [案件を変更したか, エラー（なければ nil）]
      def change_engagement_if_requested
        new_engagement_id = adr_params[:engagement_id]
        return [ false, nil ] if new_engagement_id.blank? || new_engagement_id.to_i == @adr.engagement_id

        engagement = ::AdrManagement::Engagement.find(new_engagement_id)
        result = ::AdrManagement::ChangeAdrEngagement.perform(
          adr: @adr, engagement: engagement, origin: web_origin
        )
        result.success? ? [ true, nil ] : [ false, result.errors ]
      end

      def superseded_numbers_param
        Array(params[:superseded_numbers]).reject(&:blank?).map(&:to_i)
      end

      def web_origin
        "admin:#{current_admin_email}"
      end

      def adr_params
        params.require(:adr_management_adr).permit(
          :engagement_id, :project_id, :title, :status, :confidence, :decided_on,
          :context, :decision, :consequences, :alternatives,
          :reevaluation_conditions, :reference_links
        )
      end
    end
  end
end
