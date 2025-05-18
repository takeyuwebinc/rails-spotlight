# AssetPathResolverサービス
#
# Markdown内の画像パスを解決するためのサービスクラスです。
# 相対パスをAsset Pipeline対応のパスに変換します。
class AssetPathResolver < ApplicationService
  attr_reader :path

  # 初期化
  #
  # @param path [String] 解決対象の画像パス
  def initialize(path)
    @path = path
  end

  # パスを解決する
  #
  # @return [String] 解決後のパス
  def call
    # 幅指定を削除（スペースも含めて削除）
    clean_path = path.gsub(/\s*=\s*\d+px\s*$/, "").strip

    # パスの種類に応じて処理
    if clean_path.start_with?("http://", "https://")
      # URLの場合はそのまま返す
      clean_path
    elsif clean_path.start_with?("/")
      # 絶対パスの場合もそのまま返す
      clean_path
    else
      # 相対パスの場合はApplicationController.helpersからimage_pathヘルパーを使用
      ApplicationController.helpers.image_path(clean_path)
    end
  end
end
