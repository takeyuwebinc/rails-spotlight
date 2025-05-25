# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_05_25_073625) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "article_tags", force: :cascade do |t|
    t.integer "article_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["article_id", "tag_id"], name: "index_article_tags_on_article_id_and_tag_id", unique: true
    t.index ["article_id"], name: "index_article_tags_on_article_id"
    t.index ["tag_id"], name: "index_article_tags_on_tag_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title"
    t.string "slug"
    t.text "description"
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "content"
    t.index ["published_at"], name: "index_articles_on_published_at"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
  end

  create_table "link_metadata", force: :cascade do |t|
    t.string "url", null: false
    t.string "title", default: "", null: false
    t.text "description", default: "", null: false
    t.string "domain", default: "", null: false
    t.string "favicon", default: "", null: false
    t.string "image_url", default: "", null: false
    t.datetime "last_fetched_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url"], name: "index_link_metadata_on_url", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.string "title", null: false
    t.text "description", null: false
    t.string "icon", null: false
    t.string "color", null: false
    t.string "technologies", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "published_at"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "bg_color", null: false
    t.string "text_color", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "uses_items", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "category", null: false
    t.text "description", null: false
    t.string "url"
    t.integer "position", default: 999
    t.boolean "published", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category", "position"], name: "index_uses_items_on_category_and_position"
    t.index ["category"], name: "index_uses_items_on_category"
    t.index ["slug"], name: "index_uses_items_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "article_tags", "articles"
  add_foreign_key "article_tags", "tags"
end
