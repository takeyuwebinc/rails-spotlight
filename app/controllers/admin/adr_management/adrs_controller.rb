# frozen_string_literal: true

module Admin
  module AdrManagement
    class AdrsController < BaseController
      # 自然言語検索は関連度順の上位のみを返す。一覧の既定表示（絞り込みのみ・
      # 全件）と違い件数上限を設ける必要があるため、画面で扱える範囲の件数にする
      NATURAL_LANGUAGE_LIMIT = 30

      before_action :set_adr, only: %i[show edit update destroy]

      def index
        @engagements = ::AdrManagement::Engagement.order(:code)
        @natural_language_limit = NATURAL_LANGUAGE_LIMIT
        @query = params[:query].to_s.strip

        if @query.present?
          search_by_natural_language
        else
          @adrs = ordered(filtered_adrs)
        end
      end

      def show
        @revisions = @adr.revisions.recent_first
        @quality_assessments = latest_quality_assessments_by_layer
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
        # 旧 URL（DB の id ベース）からのアクセスも引き続き受け付ける
        @adr = if params[:id].to_s.match?(/\A\d+\z/)
          ::AdrManagement::Adr.find(params[:id])
        else
          ::AdrManagement::Adr.find_by_display_number!(params[:id])
        end
      end

      # 層ごとの最新評価が現在の品質状態を表す。新しい評価の作成時に同じ層の
      # 旧評価の未処理所見は自動クローズされるため、未処理所見は最新の1件にしか
      # 残らない。評価が無い層は nil（未評価）として表示する
      def latest_quality_assessments_by_layer
        ::AdrManagement::QualityAssessment::LAYERS.index_with do |layer|
          @adr.quality_assessments.where(layer: layer).recent_first.first
        end
      end

      # 自然言語検索の検索対象にもなるため、表示用の並び順と関連付けの
      # 先読みは含めない（絞り込み条件だけを表すリレーションを返す）
      def filtered_adrs
        adrs = ::AdrManagement::Adr.all
        adrs = adrs.where(engagement_id: params[:engagement_id]) if params[:engagement_id].present?
        adrs = adrs.where(status: params[:status]) if params[:status].present?
        adrs = adrs.keyword_match(params[:keyword]) if params[:keyword].present?
        adrs
      end

      def ordered(adrs)
        adrs.includes(:engagement).order(decided_on: :desc, id: :desc)
      end

      # 絞り込み後の ADR を対象に関連度順で上位を返す。埋め込み API が使えない
      # ときは画面を失敗させず、絞り込みのみの一覧に縮退する（索引は自然言語
      # 検索専用であり、DB を参照する一覧は索引が古くても正しさを保つ）
      def search_by_natural_language
        result = ::AdrManagement::SearchNaturalLanguage.perform(
          query: @query, adr_scope: filtered_adrs, limit: NATURAL_LANGUAGE_LIMIT
        )

        if result.failure?
          flash.now[:alert] = result.errors.map(&:message).join(" / ")
          @adrs = ordered(filtered_adrs)
          return
        end

        @adrs = result.data.map(&:adr)
        @relevance_scores = result.data.to_h { |scored| [ scored.adr.id, scored.score ] }
        record_natural_language_search_log(result.data)
      end

      # 0件検索は管理画面のレビューキュー、実行数・0件率は検索品質レポートの
      # 母数になる。指標が Agent 経由の検索に偏らないよう管理画面からの検索も残す
      def record_natural_language_search_log(scored)
        engagement = if params[:engagement_id].present?
          ::AdrManagement::Engagement.find_by(id: params[:engagement_id])
        end

        ::AdrManagement::SearchLog.record(
          mode: "natural_language",
          query: @query,
          keyword: params[:keyword].presence,
          engagement: engagement,
          filters: { status: params[:status].presence },
          results: scored.map { |entry| { adr_id: entry.adr.id, score: entry.score.round(4) } },
          result_count: scored.size,
          origin: web_origin
        )
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
