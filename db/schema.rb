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

ActiveRecord::Schema[8.1].define(version: 2026_07_20_090000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "adr_management_adr_chunks", force: :cascade do |t|
    t.integer "adr_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.binary "embedding"
    t.string "kind", null: false
    t.string "state", default: "stale", null: false
    t.datetime "updated_at", null: false
    t.index ["adr_id"], name: "index_adr_management_adr_chunks_on_adr_id"
    t.index ["state"], name: "index_adr_management_adr_chunks_on_state"
  end

  create_table "adr_management_adr_revisions", force: :cascade do |t|
    t.integer "adr_id", null: false
    t.string "change_type", null: false
    t.json "changed_fields"
    t.datetime "created_at", null: false
    t.string "origin", null: false
    t.json "snapshot"
    t.index ["adr_id"], name: "index_adr_management_adr_revisions_on_adr_id"
  end

  create_table "adr_management_adrs", force: :cascade do |t|
    t.text "alternatives"
    t.string "confidence", null: false
    t.text "consequences", null: false
    t.text "context", null: false
    t.datetime "created_at", null: false
    t.date "decided_on", null: false
    t.text "decision", null: false
    t.integer "engagement_id", null: false
    t.integer "number", null: false
    t.integer "project_id"
    t.text "reevaluation_conditions"
    t.text "reference_links"
    t.string "status", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["engagement_id", "number"], name: "idx_adr_management_adrs_on_engagement_and_number", unique: true
    t.index ["project_id"], name: "index_adr_management_adrs_on_project_id"
  end

  create_table "adr_management_clients", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_adr_management_clients_on_client_id", unique: true
  end

  create_table "adr_management_engagements", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "max_issued_number", default: 0, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_adr_management_engagements_on_client_id"
    t.index ["code"], name: "index_adr_management_engagements_on_code", unique: true
  end

  create_table "adr_management_projects", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date"
    t.integer "engagement_id", null: false
    t.string "name", null: false
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index ["engagement_id"], name: "index_adr_management_projects_on_engagement_id"
  end

  create_table "adr_management_reevaluation_checks", force: :cascade do |t|
    t.integer "adr_id", null: false
    t.date "checked_on", null: false
    t.datetime "created_at", null: false
    t.text "note"
    t.string "origin", null: false
    t.string "result", null: false
    t.index ["adr_id", "checked_on"], name: "idx_adr_reevaluation_checks_on_adr_and_checked_on"
  end

  create_table "adr_management_supersessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "superseded_adr_id", null: false
    t.integer "superseding_adr_id", null: false
    t.index ["superseded_adr_id"], name: "idx_adr_management_supersessions_on_superseded", unique: true
    t.index ["superseding_adr_id"], name: "idx_adr_management_supersessions_on_superseding"
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "last_error"
    t.integer "model_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_chats_on_model_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_clients_on_code", unique: true
  end

  create_table "content_agent_pending_changes", force: :cascade do |t|
    t.datetime "applied_at"
    t.text "apply_error"
    t.integer "chat_id", null: false
    t.datetime "created_at", null: false
    t.integer "message_id"
    t.string "operation", null: false
    t.json "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "target_id"
    t.string "target_type", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id", "status"], name: "index_content_agent_pending_changes_on_chat_id_and_status"
    t.index ["chat_id"], name: "index_content_agent_pending_changes_on_chat_id"
    t.index ["message_id"], name: "index_content_agent_pending_changes_on_message_id"
  end

  create_table "content_agent_task_usages", force: :cascade do |t|
    t.integer "chat_id", null: false
    t.datetime "created_at", null: false
    t.integer "input_tokens", default: 0, null: false
    t.string "model_id", null: false
    t.integer "output_tokens", default: 0, null: false
    t.string "task_kind", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_content_agent_task_usages_on_chat_id"
  end

  create_table "link_metadata", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", default: "", null: false
    t.string "domain", default: "", null: false
    t.string "favicon", default: "", null: false
    t.string "image_url", default: "", null: false
    t.datetime "last_fetched_at", null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.string "url", null: false
    t.index ["url"], name: "index_link_metadata_on_url", unique: true
  end

  create_table "messages", force: :cascade do |t|
    t.integer "cache_creation_tokens"
    t.integer "cached_tokens"
    t.integer "chat_id", null: false
    t.text "content"
    t.json "content_raw"
    t.datetime "created_at", null: false
    t.integer "input_tokens"
    t.integer "model_id"
    t.integer "output_tokens"
    t.string "role", null: false
    t.text "thinking_signature"
    t.text "thinking_text"
    t.integer "thinking_tokens"
    t.integer "tool_call_id"
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
    t.index ["tool_call_id"], name: "index_messages_on_tool_call_id"
  end

  create_table "models", force: :cascade do |t|
    t.json "capabilities", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "family"
    t.date "knowledge_cutoff"
    t.integer "max_output_tokens"
    t.json "metadata", default: {}
    t.json "modalities", default: {}
    t.datetime "model_created_at"
    t.string "model_id", null: false
    t.string "name", null: false
    t.json "pricing", default: {}
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["family"], name: "index_models_on_family"
    t.index ["provider", "model_id"], name: "index_models_on_provider_and_model_id", unique: true
    t.index ["provider"], name: "index_models_on_provider"
  end

  create_table "oauth_access_grants", force: :cascade do |t|
    t.integer "application_id", null: false
    t.string "code_challenge"
    t.string "code_challenge_method"
    t.datetime "created_at", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "resource_owner_id", null: false
    t.datetime "revoked_at"
    t.string "scopes", default: "", null: false
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", force: :cascade do |t|
    t.integer "application_id", null: false
    t.datetime "created_at", null: false
    t.integer "expires_in"
    t.string "previous_refresh_token", default: "", null: false
    t.string "refresh_token"
    t.string "resource_owner_id"
    t.datetime "revoked_at"
    t.string "scopes"
    t.string "token", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", force: :cascade do |t|
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.string "secret", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "projects", force: :cascade do |t|
    t.string "color", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "icon", null: false
    t.integer "position"
    t.datetime "published_at"
    t.string "technologies", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "slide_pages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "position", null: false
    t.integer "slide_id", null: false
    t.datetime "updated_at", null: false
    t.index ["slide_id", "position"], name: "index_slide_pages_on_slide_id_and_position", unique: true
    t.index ["slide_id"], name: "index_slide_pages_on_slide_id"
  end

  create_table "slide_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "slide_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["slide_id", "tag_id"], name: "index_slide_tags_on_slide_id_and_tag_id", unique: true
    t.index ["slide_id"], name: "index_slide_tags_on_slide_id"
    t.index ["tag_id"], name: "index_slide_tags_on_tag_id"
  end

  create_table "slides", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.datetime "published_at", null: false
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_slides_on_published_at"
    t.index ["slug"], name: "index_slides_on_slug", unique: true
  end

  create_table "speaking_engagement_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "speaking_engagement_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["speaking_engagement_id", "tag_id"], name: "idx_on_speaking_engagement_id_tag_id_6ba35e291c", unique: true
    t.index ["speaking_engagement_id"], name: "index_speaking_engagement_tags_on_speaking_engagement_id"
    t.index ["tag_id"], name: "index_speaking_engagement_tags_on_tag_id"
  end

  create_table "speaking_engagements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.date "event_date", null: false
    t.string "event_name", null: false
    t.string "event_url"
    t.string "location"
    t.integer "position", default: 999
    t.boolean "published", default: true
    t.string "slides_url"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["event_date"], name: "index_speaking_engagements_on_event_date"
    t.index ["published", "event_date"], name: "index_speaking_engagements_on_published_and_event_date"
    t.index ["slug"], name: "index_speaking_engagements_on_slug", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "bg_color", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "text_color", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "tool_calls", force: :cascade do |t|
    t.json "arguments", default: {}
    t.datetime "created_at", null: false
    t.integer "message_id", null: false
    t.string "name", null: false
    t.text "thought_signature"
    t.string "tool_call_id", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
    t.index ["name"], name: "index_tool_calls_on_name"
    t.index ["tool_call_id"], name: "index_tool_calls_on_tool_call_id", unique: true
  end

  create_table "uses_items", force: :cascade do |t|
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.boolean "discontinued", default: false, null: false
    t.string "name", null: false
    t.integer "position", default: 999
    t.boolean "published", default: true
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["category", "position"], name: "index_uses_items_on_category_and_position"
    t.index ["category"], name: "index_uses_items_on_category"
    t.index ["slug"], name: "index_uses_items_on_slug", unique: true
  end

  create_table "work_hour_clients", force: :cascade do |t|
    t.integer "client_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_work_hour_clients_on_client_id", unique: true
  end

  create_table "work_hour_project_monthly_estimates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "estimated_hours", precision: 5, scale: 1, null: false
    t.integer "project_id", null: false
    t.datetime "updated_at", null: false
    t.date "year_month", null: false
    t.index ["project_id", "year_month"], name: "idx_work_hour_estimates_on_project_and_month", unique: true
    t.index ["project_id"], name: "index_work_hour_project_monthly_estimates_on_project_id"
  end

  create_table "work_hour_projects", force: :cascade do |t|
    t.decimal "budget_hours", precision: 7, scale: 1
    t.integer "client_id"
    t.string "code", null: false
    t.string "color", default: "#6366f1", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "name", null: false
    t.date "start_date"
    t.string "status", default: "active", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_work_hour_projects_on_client_id"
    t.index ["code"], name: "index_work_hour_projects_on_code", unique: true
  end

  create_table "work_hour_work_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "minutes", null: false
    t.integer "project_id"
    t.date "target_month", null: false
    t.datetime "updated_at", null: false
    t.date "worked_on", null: false
    t.index ["project_id"], name: "index_work_hour_work_entries_on_project_id"
    t.index ["target_month"], name: "index_work_hour_work_entries_on_target_month"
    t.index ["worked_on"], name: "index_work_hour_work_entries_on_worked_on"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "chats", "models"
  add_foreign_key "content_agent_pending_changes", "chats"
  add_foreign_key "content_agent_pending_changes", "messages"
  add_foreign_key "content_agent_task_usages", "chats"
  add_foreign_key "messages", "chats"
  add_foreign_key "messages", "models"
  add_foreign_key "messages", "tool_calls"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "slide_pages", "slides"
  add_foreign_key "slide_tags", "slides"
  add_foreign_key "slide_tags", "tags"
  add_foreign_key "speaking_engagement_tags", "speaking_engagements"
  add_foreign_key "speaking_engagement_tags", "tags"
  add_foreign_key "tool_calls", "messages"
  add_foreign_key "work_hour_project_monthly_estimates", "work_hour_projects", column: "project_id"
  add_foreign_key "work_hour_projects", "work_hour_clients", column: "client_id"
  add_foreign_key "work_hour_work_entries", "work_hour_projects", column: "project_id"
end
