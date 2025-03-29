class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :title, null: false, comment: 'プロジェクトのタイトル'
      t.text :description, null: false, comment: 'プロジェクトの説明'
      t.string :icon, null: false, comment: 'プロジェクトのアイコン（Font Awesome）'
      t.string :color, null: false, comment: 'アイコンの背景色'
      t.string :technologies, null: false, comment: '使用技術（カンマ区切り）'
      t.integer :position, comment: '表示順序'

      t.timestamps
    end
  end
end
