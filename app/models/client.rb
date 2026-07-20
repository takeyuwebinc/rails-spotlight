# frozen_string_literal: true

# 取引先のドメイン横断共有基盤（共有カーネル）。
# ドメインによらない識別属性（code・name）のみを持ち、ドメイン固有の
# 属性・振る舞いは各ドメインの拡張モデル側に置く。code は全ドメイン一意で、
# 同一取引先をドメイン間で同一視するためのキーとなる。
class Client < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
end
