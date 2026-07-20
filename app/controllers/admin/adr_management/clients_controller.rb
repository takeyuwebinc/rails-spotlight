# frozen_string_literal: true

module Admin
  module AdrManagement
    class ClientsController < BaseController
      before_action :set_client, only: %i[show edit update destroy]

      def index
        @clients = ::AdrManagement::Client.includes(:engagements).ordered_by_code
      end

      def show
      end

      def new
        @client = ::AdrManagement::Client.new
      end

      def edit
      end

      def create
        @client = ::AdrManagement::Client.new(client_params)

        if @client.save
          redirect_to admin_adr_management_clients_path, notice: "クライアントを作成しました。"
        else
          render :new, status: :unprocessable_entity
        end
      end

      def update
        if @client.update(client_params)
          redirect_to admin_adr_management_clients_path, notice: "クライアントを更新しました。"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        if @client.destroy
          redirect_to admin_adr_management_clients_path, notice: "クライアントを削除しました。"
        else
          redirect_to admin_adr_management_clients_path,
            alert: "削除できません: #{@client.errors.full_messages.to_sentence}"
        end
      end

      private

      def set_client
        @client = ::AdrManagement::Client.find(params[:id])
      end

      def client_params
        params.require(:adr_management_client).permit(:code, :name)
      end
    end
  end
end
