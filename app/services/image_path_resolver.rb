# ImagePathResolverサービス
#
# Markdown内の画像パスを解決するためのサービスクラスです。
# 相対パスをAsset Pipeline対応のパスに変換します。
class ImagePathResolver < ApplicationService
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
    # パスの種類に応じて処理
    if path.start_with?("http://", "https://")
      # URLの場合はそのまま返す
      path
    elsif path.start_with?("/")
      # 絶対パスの場合もそのまま返す
      path
    else
      # 相対パスの場合はApplicationController.helpersからimage_pathヘルパーを使用
      ApplicationController.helpers.image_path(path)
    end
  end
end
