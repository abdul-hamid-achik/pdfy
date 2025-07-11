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

ActiveRecord::Schema[8.0].define(version: 2025_07_08_021209) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_admin_comments", force: :cascade do |t|
    t.string "namespace"
    t.text "body"
    t.string "resource_type"
    t.bigint "resource_id"
    t.string "author_type"
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_type", "author_id"], name: "index_active_admin_comments_on_author"
    t.index ["namespace"], name: "index_active_admin_comments_on_namespace"
    t.index ["resource_type", "resource_id"], name: "index_active_admin_comments_on_resource"
  end

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

  create_table "admin_users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_admin_users_on_reset_password_token", unique: true
  end

  create_table "data_points", force: :cascade do |t|
    t.bigint "data_source_id", null: false
    t.string "key", null: false
    t.json "value", null: false
    t.datetime "fetched_at", null: false
    t.datetime "expires_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id", "key"], name: "index_data_points_on_data_source_id_and_key"
    t.index ["data_source_id"], name: "index_data_points_on_data_source_id"
    t.index ["expires_at"], name: "index_data_points_on_expires_at"
    t.index ["fetched_at"], name: "index_data_points_on_fetched_at"
  end

  create_table "data_sources", force: :cascade do |t|
    t.string "name", null: false
    t.string "source_type", null: false
    t.string "api_endpoint", null: false
    t.string "api_key"
    t.json "configuration", default: {}
    t.boolean "active", default: true, null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_data_sources_on_active"
    t.index ["source_type"], name: "index_data_sources_on_source_type"
    t.index ["user_id", "name"], name: "index_data_sources_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_data_sources_on_user_id"
  end

  create_table "pdf_templates", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.text "template_content", null: false
    t.json "template_variables", default: {}
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["active"], name: "index_pdf_templates_on_active"
    t.index ["name"], name: "index_pdf_templates_on_name", unique: true
    t.index ["user_id"], name: "index_pdf_templates_on_user_id"
  end

  create_table "processed_pdfs", force: :cascade do |t|
    t.integer "pdf_template_id", null: false
    t.text "original_html", null: false
    t.json "variables_used", default: {}
    t.datetime "generated_at", null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["generated_at"], name: "index_processed_pdfs_on_generated_at"
    t.index ["pdf_template_id"], name: "index_processed_pdfs_on_pdf_template_id"
  end

  create_table "template_data_sources", force: :cascade do |t|
    t.bigint "pdf_template_id", null: false
    t.bigint "data_source_id", null: false
    t.boolean "enabled", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_source_id"], name: "index_template_data_sources_on_data_source_id"
    t.index ["pdf_template_id", "data_source_id"], name: "index_template_data_sources_unique", unique: true
    t.index ["pdf_template_id"], name: "index_template_data_sources_on_pdf_template_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "data_points", "data_sources"
  add_foreign_key "data_sources", "users"
  add_foreign_key "pdf_templates", "users"
  add_foreign_key "processed_pdfs", "pdf_templates"
  add_foreign_key "template_data_sources", "data_sources"
  add_foreign_key "template_data_sources", "pdf_templates"
end
