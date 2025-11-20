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

ActiveRecord::Schema[8.0].define(version: 2025_11_20_134130) do
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

  create_table "affiliate_bookings", force: :cascade do |t|
    t.bigint "affiliate_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity"
    t.decimal "price"
    t.string "status"
    t.date "booking_date"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["affiliate_id"], name: "index_affiliate_bookings_on_affiliate_id"
    t.index ["product_id"], name: "index_affiliate_bookings_on_product_id"
  end

  create_table "affiliates", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.string "password_digest"
    t.string "location"
    t.decimal "commission_rate"
    t.decimal "total_earnings"
    t.string "status"
    t.boolean "active"
    t.string "referral_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
