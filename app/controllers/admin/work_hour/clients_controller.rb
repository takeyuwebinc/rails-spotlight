# frozen_string_literal: true

module Admin
  module WorkHour
    class ClientsController < BaseController
      before_action :set_client, only: %i[show edit update destroy]

      def index
        @clients = ::WorkHour::Client.order(:name)
      end

      def show
      end

      def new
        @client = ::WorkHour::Client.new
      end

      def edit
      end

      def create
        @client = ::WorkHour::Client.new(client_params)

        if @client.save
          redirect_to admin_work_hour_clients_path, notice: "クライアントを作成しました。"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @client.update(client_params)
          redirect_to admin_work_hour_clients_path, notice: "クライアントを更新しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @client.destroy
        redirect_to admin_work_hour_clients_path, notice: "クライアントを削除しました。"
      end

      private

      def set_client
        @client = ::WorkHour::Client.find(params[:id])
      end

      def client_params
        params.require(:work_hour_client).permit(:code, :name)
      end
    end
  end
end
