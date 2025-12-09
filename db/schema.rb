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

ActiveRecord::Schema[8.0].define(version: 2025_12_09_114932) do
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

  create_table "slide_pages", force: :cascade do |t|
    t.integer "slide_id", null: false
    t.text "content", null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slide_id", "position"], name: "index_slide_pages_on_slide_id_and_position", unique: true
    t.index ["slide_id"], name: "index_slide_pages_on_slide_id"
  end

  create_table "slide_tags", force: :cascade do |t|
    t.integer "slide_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slide_id", "tag_id"], name: "index_slide_tags_on_slide_id_and_tag_id", unique: true
    t.index ["slide_id"], name: "index_slide_tags_on_slide_id"
    t.index ["tag_id"], name: "index_slide_tags_on_tag_id"
  end

  create_table "slides", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description", null: false
    t.datetime "published_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_slides_on_published_at"
    t.index ["slug"], name: "index_slides_on_slug", unique: true
  end

  create_table "speaking_engagement_tags", force: :cascade do |t|
    t.integer "speaking_engagement_id", null: false
    t.integer "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["speaking_engagement_id", "tag_id"], name: "idx_on_speaking_engagement_id_tag_id_6ba35e291c", unique: true
    t.index ["speaking_engagement_id"], name: "index_speaking_engagement_tags_on_speaking_engagement_id"
    t.index ["tag_id"], name: "index_speaking_engagement_tags_on_tag_id"
  end

  create_table "speaking_engagements", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.string "event_name", null: false
    t.date "event_date", null: false
    t.string "location"
    t.text "description"
    t.string "event_url"
    t.string "slides_url"
    t.integer "position", default: 999
    t.boolean "published", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_date"], name: "index_speaking_engagements_on_event_date"
    t.index ["published", "event_date"], name: "index_speaking_engagements_on_published_and_event_date"
    t.index ["slug"], name: "index_speaking_engagements_on_slug", unique: true
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
  add_foreign_key "slide_pages", "slides"
  add_foreign_key "slide_tags", "slides"
  add_foreign_key "slide_tags", "tags"
  add_foreign_key "speaking_engagement_tags", "speaking_engagements"
  add_foreign_key "speaking_engagement_tags", "tags"
end
