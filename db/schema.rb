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

ActiveRecord::Schema[7.1].define(version: 2026_10_07_150000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "admin_users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admin_users_on_email", unique: true
  end

  create_table "api_keys", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.string "key_digest", null: false
    t.string "prefix", null: false
    t.string "label"
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key_digest"], name: "index_api_keys_on_key_digest", unique: true
    t.index ["merchant_id"], name: "index_api_keys_on_merchant_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.bigint "admin_user_id"
    t.string "action", null: false
    t.string "target_type"
    t.bigint "target_id"
    t.jsonb "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["admin_user_id"], name: "index_audit_logs_on_admin_user_id"
  end

  create_table "check_ledger_entries", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.integer "delta", null: false
    t.bigint "balance_after", null: false
    t.string "reason", null: false
    t.string "ref_type"
    t.bigint "ref_id"
    t.string "memo"
    t.datetime "created_at", null: false
    t.index ["merchant_id", "created_at"], name: "index_check_ledger_entries_on_merchant_id_and_created_at"
    t.index ["merchant_id"], name: "index_check_ledger_entries_on_merchant_id"
  end

  create_table "fraud_reports", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.string "phone_hash", null: false
    t.text "phone_ciphertext", null: false
    t.string "phone_last4", null: false
    t.string "reason_code", null: false
    t.string "notes", limit: 500
    t.datetime "incident_at"
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "legal_hold", default: false, null: false
    t.index ["merchant_id", "phone_hash"], name: "index_fraud_reports_on_merchant_id_and_phone_hash", unique: true
    t.index ["merchant_id"], name: "index_fraud_reports_on_merchant_id"
    t.index ["phone_hash"], name: "index_fraud_reports_on_phone_hash"
  end

  create_table "merchant_users", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "email_verified_at"
    t.string "otp_digest"
    t.datetime "otp_expires_at"
    t.integer "otp_attempts", default: 0, null: false
    t.datetime "otp_last_sent_at"
    t.integer "otp_sends_in_window", default: 0, null: false
    t.datetime "otp_window_started_at"
    t.index ["email"], name: "index_merchant_users_on_email", unique: true
    t.index ["merchant_id"], name: "index_merchant_users_on_merchant_id", unique: true
  end

  create_table "merchants", force: :cascade do |t|
    t.string "name", null: false
    t.string "business_name", null: false
    t.string "website"
    t.string "gstin"
    t.string "contact_email", null: false
    t.string "phone"
    t.string "status", default: "pending", null: false
    t.bigint "checks_remaining", default: 0, null: false
    t.string "rejection_reason"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "terms_accepted_at"
    t.string "terms_version"
    t.string "terms_accepted_ip"
    t.index ["contact_email"], name: "index_merchants_on_contact_email", unique: true
    t.index ["status"], name: "index_merchants_on_status"
  end

  add_foreign_key "api_keys", "merchants"
  add_foreign_key "audit_logs", "admin_users"
  add_foreign_key "check_ledger_entries", "merchants"
  add_foreign_key "fraud_reports", "merchants"
  add_foreign_key "merchant_users", "merchants"
end
