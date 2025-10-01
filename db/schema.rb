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

ActiveRecord::Schema[8.0].define(version: 2025_09_30_170332) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "admin_settings", force: :cascade do |t|
    t.string "business_name"
    t.text "address"
    t.string "mobile"
    t.string "email"
    t.string "gstin"
    t.string "pan_number"
    t.string "account_holder_name"
    t.string "bank_name"
    t.string "account_number"
    t.string "ifsc_code"
    t.string "upi_id"
    t.text "terms_and_conditions"
    t.string "qr_code_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "faq"
    t.text "contact_us"
    t.text "privacy_policy"
  end

  create_table "advertisements", force: :cascade do |t|
    t.string "name", null: false
    t.string "image_url"
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "status", default: "active"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["end_date"], name: "index_advertisements_on_end_date"
    t.index ["start_date", "end_date"], name: "index_advertisements_on_start_date_and_end_date"
    t.index ["start_date"], name: "index_advertisements_on_start_date"
    t.index ["status"], name: "index_advertisements_on_status"
    t.index ["user_id"], name: "index_advertisements_on_user_id"
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "color", null: false
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["is_active"], name: "index_categories_on_is_active"
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "cms_pages", force: :cascade do |t|
    t.string "slug", null: false
    t.string "version", default: "v1.0", null: false
    t.string "title", null: false
    t.text "content", null: false
    t.string "locale", default: "en", null: false
    t.datetime "published_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["published_at"], name: "index_cms_pages_on_published_at"
    t.index ["slug", "locale"], name: "index_cms_pages_on_slug_and_locale", unique: true
  end

  create_table "coupons", force: :cascade do |t|
    t.string "code"
    t.decimal "amount"
    t.text "description"
    t.datetime "expires_at"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "customer_addresses", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "address_type"
    t.text "street_address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "landmark"
    t.boolean "is_default"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_addresses_on_customer_id"
  end

  create_table "customer_points", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.decimal "points", precision: 10, scale: 2, default: "0.0"
    t.string "action_type", null: false
    t.integer "reference_id"
    t.string "reference_type"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "action_type"], name: "index_customer_points_on_customer_id_and_action_type"
    t.index ["customer_id"], name: "index_customer_points_on_customer_id"
    t.index ["reference_type", "reference_id"], name: "index_customer_points_on_reference_type_and_reference_id"
  end

  create_table "customer_preferences", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "language"
    t.time "delivery_time_start"
    t.time "delivery_time_end"
    t.boolean "skip_weekends"
    t.text "special_instructions"
    t.text "notification_preferences"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "referral_code"
    t.decimal "referral_earnings", precision: 10, scale: 2, default: "0.0"
    t.text "address_request_notes"
    t.boolean "referral_enabled", default: true
    t.index ["customer_id"], name: "index_customer_preferences_on_customer_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.decimal "latitude"
    t.decimal "longitude"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "delivery_person_id"
    t.string "image_url"
    t.string "phone_number"
    t.string "email"
    t.string "gst_number"
    t.string "pan_number"
    t.string "member_id"
    t.string "shipping_address"
    t.string "preferred_language"
    t.string "delivery_time_preference"
    t.string "notification_method"
    t.string "alt_phone_number"
    t.string "profile_image_url"
    t.string "address_landmark"
    t.string "address_type"
    t.boolean "is_active", default: true
    t.string "password_digest"
    t.string "pincode"
    t.string "landmark"
    t.string "city"
    t.string "postal_code"
    t.string "state"
    t.string "address_line"
    t.string "full_address"
    t.string "country"
    t.integer "customer_type", default: 0
    t.text "interval_days"
    t.integer "regular_quantity"
    t.integer "regular_product_id"
    t.string "regular_delivery_person"
    t.string "regular_delivery_person_from_assignment"
    t.string "monthly_pattern", default: "irregular"
    t.datetime "pattern_updated_at"
    t.integer "invoices_count", default: 0, null: false
    t.decimal "wallet_amount", precision: 10, scale: 2, default: "50.0", null: false
    t.datetime "invoice_created_at"
    t.datetime "invoice_sent_at"
    t.index ["alt_phone_number"], name: "index_customers_on_alt_phone_number", where: "(alt_phone_number IS NOT NULL)"
    t.index ["created_at"], name: "idx_customers_created_at"
    t.index ["customer_type"], name: "index_customers_on_customer_type"
    t.index ["delivery_person_id", "is_active"], name: "index_customers_delivery_person_active"
    t.index ["delivery_person_id"], name: "index_customers_on_delivery_person_id"
    t.index ["email"], name: "index_customers_on_email", where: "(email IS NOT NULL)"
    t.index ["is_active"], name: "index_customers_on_is_active"
    t.index ["latitude", "longitude"], name: "index_customers_on_latitude_and_longitude", where: "((latitude IS NOT NULL) AND (longitude IS NOT NULL))"
    t.index ["member_id"], name: "index_customers_on_member_id", unique: true, where: "(member_id IS NOT NULL)"
    t.index ["monthly_pattern"], name: "index_customers_on_monthly_pattern"
    t.index ["name"], name: "index_customers_on_name"
    t.index ["preferred_language"], name: "index_customers_on_preferred_language"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "deliveries", force: :cascade do |t|
    t.integer "delivery_person_id"
    t.bigint "customer_id", null: false
    t.string "status"
    t.date "delivery_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_deliveries_on_customer_id"
  end

  create_table "delivery_assignments", force: :cascade do |t|
    t.bigint "delivery_schedule_id"
    t.bigint "customer_id", null: false
    t.bigint "user_id", null: false
    t.date "scheduled_date"
    t.string "status"
    t.datetime "completed_at"
    t.bigint "product_id", null: false
    t.float "quantity"
    t.string "unit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "invoice_generated", default: false
    t.bigint "invoice_id"
    t.integer "delivery_person_id"
    t.text "special_instructions"
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "final_amount_after_discount", precision: 10, scale: 2
    t.text "cancellation_reason"
    t.integer "booked_by"
    t.index ["customer_id", "scheduled_date", "product_id"], name: "index_da_on_customer_date_product"
    t.index ["customer_id", "scheduled_date", "status"], name: "index_delivery_assignments_customer_date_status"
    t.index ["customer_id", "scheduled_date"], name: "index_delivery_assignments_on_customer_and_date"
    t.index ["customer_id", "scheduled_date"], name: "index_delivery_assignments_on_customer_id_and_scheduled_date"
    t.index ["customer_id"], name: "index_delivery_assignments_on_customer_id"
    t.index ["delivery_schedule_id"], name: "index_delivery_assignments_on_delivery_schedule_id"
    t.index ["discount_amount"], name: "index_delivery_assignments_on_discount_amount"
    t.index ["final_amount_after_discount"], name: "index_delivery_assignments_on_final_amount_after_discount"
    t.index ["invoice_generated"], name: "index_delivery_assignments_on_invoice_generated"
    t.index ["invoice_id"], name: "index_delivery_assignments_on_invoice_id"
    t.index ["product_id", "scheduled_date", "quantity"], name: "index_delivery_assignments_product_date_quantity"
    t.index ["product_id", "scheduled_date", "status"], name: "index_delivery_assignments_composite"
    t.index ["product_id", "status", "completed_at"], name: "idx_delivery_product_status_completed"
    t.index ["product_id", "status", "scheduled_date"], name: "idx_delivery_product_status_date"
    t.index ["product_id"], name: "index_delivery_assignments_on_product_id"
    t.index ["scheduled_date", "customer_id"], name: "index_delivery_assignments_on_date_and_customer"
    t.index ["scheduled_date", "final_amount_after_discount", "quantity"], name: "idx_delivery_assignments_date_revenue_qty"
    t.index ["scheduled_date", "final_amount_after_discount"], name: "index_delivery_assignments_date_revenue"
    t.index ["scheduled_date", "product_id", "quantity"], name: "idx_delivery_assignments_completed_date_product", where: "((status)::text = 'completed'::text)"
    t.index ["scheduled_date", "product_id"], name: "index_delivery_assignments_completed", where: "((status)::text = 'completed'::text)"
    t.index ["scheduled_date", "quantity", "final_amount_after_discount"], name: "idx_delivery_assignments_date_qty_amount"
    t.index ["scheduled_date", "quantity", "final_amount_after_discount"], name: "index_delivery_assignments_date_qty_revenue"
    t.index ["scheduled_date", "status", "product_id"], name: "idx_delivery_assignments_date_status_product"
    t.index ["scheduled_date", "status"], name: "index_delivery_assignments_on_date_and_status"
    t.index ["status", "completed_at", "product_id"], name: "idx_delivery_status_completed_product"
    t.index ["status", "completed_at"], name: "idx_delivery_status_completed_at"
    t.index ["status", "scheduled_date"], name: "idx_delivery_status_scheduled_date"
    t.index ["user_id"], name: "index_delivery_assignments_on_user_id"
  end
