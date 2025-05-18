# ApplicationService基底クラス
#
# サービスオブジェクトの基底クラスとして機能します。
# 各サービスクラスはこのクラスを継承し、callメソッドを実装します。
class ApplicationService
  # クラスメソッドとしてcallを定義し、新しいインスタンスを作成して実行
  #
  # @param args [Array] サービスクラスのinitializeメソッドに渡す引数
  # @param kwargs [Hash] サービスクラスのinitializeメソッドに渡すキーワード引数
  # @return [Object] callメソッドの戻り値
  def self.call(*args, **kwargs)
    new(*args, **kwargs).call
  end

  # 各サービスクラスで実装すべきメソッド
  #
  # @raise [NotImplementedError] このメソッドをオーバーライドせずに呼び出した場合
  # @return [Object] サービスの実行結果
  def call
    raise NotImplementedError, "#{self.class}#call must be implemented"
  end
end
