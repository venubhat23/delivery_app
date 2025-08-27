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

ActiveRecord::Schema[8.0].define(version: 2025_08_27_173740) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["alt_phone_number"], name: "index_customers_on_alt_phone_number", where: "(alt_phone_number IS NOT NULL)"
    t.index ["delivery_person_id"], name: "index_customers_on_delivery_person_id"
    t.index ["email"], name: "index_customers_on_email", where: "(email IS NOT NULL)"
    t.index ["is_active"], name: "index_customers_on_is_active"
    t.index ["latitude", "longitude"], name: "index_customers_on_latitude_and_longitude", where: "((latitude IS NOT NULL) AND (longitude IS NOT NULL))"
    t.index ["member_id"], name: "index_customers_on_member_id", unique: true, where: "(member_id IS NOT NULL)"
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
    t.index ["customer_id", "scheduled_date"], name: "index_delivery_assignments_on_customer_and_date"
    t.index ["customer_id", "scheduled_date"], name: "index_delivery_assignments_on_customer_id_and_scheduled_date"
    t.index ["customer_id"], name: "index_delivery_assignments_on_customer_id"
    t.index ["delivery_schedule_id"], name: "index_delivery_assignments_on_delivery_schedule_id"
    t.index ["discount_amount"], name: "index_delivery_assignments_on_discount_amount"
    t.index ["final_amount_after_discount"], name: "index_delivery_assignments_on_final_amount_after_discount"
    t.index ["invoice_generated"], name: "index_delivery_assignments_on_invoice_generated"
    t.index ["invoice_id"], name: "index_delivery_assignments_on_invoice_id"
    t.index ["product_id", "scheduled_date", "status"], name: "index_delivery_assignments_composite"
    t.index ["product_id"], name: "index_delivery_assignments_on_product_id"
    t.index ["scheduled_date", "product_id"], name: "index_delivery_assignments_completed", where: "((status)::text = 'completed'::text)"
    t.index ["scheduled_date", "status"], name: "index_delivery_assignments_on_date_and_status"
    t.index ["user_id"], name: "index_delivery_assignments_on_user_id"
  end

  create_table "delivery_items", force: :cascade do |t|
    t.bigint "delivery_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["delivery_id"], name: "index_delivery_items_on_delivery_id"
    t.index ["product_id"], name: "index_delivery_items_on_product_id"
  end

  create_table "delivery_schedules", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "user_id", null: false
    t.string "frequency"
    t.date "start_date"
    t.date "end_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "default_quantity", precision: 8, scale: 2, default: "1.0"
    t.string "default_unit", default: "pieces"
    t.bigint "product_id"
    t.integer "delivery_person_id"
    t.decimal "default_discount_amount", precision: 10, scale: 2, default: "0.0"
    t.boolean "cod", default: false
    t.index ["customer_id"], name: "index_delivery_schedules_on_customer_id"
    t.index ["default_discount_amount"], name: "index_delivery_schedules_on_default_discount_amount"
    t.index ["delivery_person_id"], name: "index_delivery_schedules_on_delivery_person_id"
    t.index ["product_id"], name: "index_delivery_schedules_on_product_id"
    t.index ["user_id"], name: "index_delivery_schedules_on_user_id"
  end

  create_table "faqs", force: :cascade do |t|
    t.string "category"
    t.text "question", null: false
    t.text "answer", null: false
    t.string "locale", default: "en", null: false
    t.boolean "is_active", default: true, null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "customer_id", null: false
    t.boolean "submitted_by_user"
    t.integer "status"
    t.text "admin_response"
    t.index ["category", "locale"], name: "index_faqs_on_category_and_locale"
    t.index ["customer_id"], name: "index_faqs_on_customer_id"
    t.index ["is_active"], name: "index_faqs_on_is_active"
    t.index ["locale"], name: "index_faqs_on_locale"
    t.index ["sort_order"], name: "index_faqs_on_sort_order"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "product_id", null: false
    t.decimal "quantity"
    t.decimal "unit_price"
    t.decimal "total_price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
    t.index ["product_id"], name: "index_invoice_items_on_product_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.float "total_amount"
    t.string "status"
    t.date "invoice_date"
    t.date "due_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invoice_number"
    t.string "invoice_type", default: "manual"
    t.datetime "paid_at"
    t.datetime "last_reminder_sent_at"
    t.text "notes"
    t.string "phone_number"
    t.string "share_token"
    t.datetime "shared_at"
    t.index ["customer_id"], name: "index_invoices_on_customer_id"
    t.index ["due_date"], name: "index_invoices_on_due_date"
    t.index ["invoice_date"], name: "index_invoices_on_invoice_date"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["invoice_type"], name: "index_invoices_on_invoice_type"
    t.index ["share_token"], name: "index_invoices_on_share_token", unique: true
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "milk_products", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "parties", force: :cascade do |t|
    t.string "name", null: false
    t.string "mobile_number", null: false
    t.string "gst_number"
    t.text "shipping_address"
    t.string "shipping_pincode"
    t.string "shipping_city"
    t.string "shipping_state"
    t.text "billing_address"
    t.string "billing_pincode"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gst_number"], name: "index_parties_on_gst_number"
    t.index ["mobile_number"], name: "index_parties_on_mobile_number"
    t.index ["name"], name: "index_parties_on_name"
    t.index ["user_id"], name: "index_parties_on_user_id"
  end

  create_table "procurement_assignments", force: :cascade do |t|
    t.bigint "procurement_schedule_id", null: false
    t.string "vendor_name", null: false
    t.date "date", null: false
    t.decimal "planned_quantity", precision: 10, scale: 2, null: false
    t.decimal "actual_quantity", precision: 10, scale: 2
    t.decimal "buying_price", precision: 10, scale: 2, null: false
    t.decimal "selling_price", precision: 10, scale: 2, null: false
    t.string "status", default: "pending"
    t.text "notes"
    t.string "unit", default: "liters"
    t.bigint "user_id", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id"
    t.index ["date"], name: "index_procurement_assignments_on_date"
    t.index ["procurement_schedule_id", "date"], name: "idx_on_procurement_schedule_id_date_cd15031368"
    t.index ["procurement_schedule_id"], name: "index_procurement_assignments_on_procurement_schedule_id"
    t.index ["product_id", "date"], name: "index_procurement_assignments_on_product_and_date"
    t.index ["product_id"], name: "index_procurement_assignments_on_product_id"
    t.index ["status", "date"], name: "index_procurement_assignments_on_status_and_date"
    t.index ["status"], name: "index_procurement_assignments_on_status"
    t.index ["user_id", "date"], name: "index_procurement_assignments_on_user_and_date"
    t.index ["user_id", "vendor_name", "date"], name: "index_procurement_assignments_composite"
    t.index ["user_id"], name: "index_procurement_assignments_on_user_id"
    t.index ["vendor_name", "date"], name: "index_procurement_assignments_on_vendor_and_date"
    t.index ["vendor_name"], name: "index_procurement_assignments_on_vendor_name"
  end

  create_table "procurement_schedules", force: :cascade do |t|
    t.string "vendor_name", null: false
    t.date "from_date", null: false
    t.date "to_date", null: false
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.decimal "buying_price", precision: 10, scale: 2, null: false
    t.decimal "selling_price", precision: 10, scale: 2, null: false
    t.string "status", default: "active"
    t.bigint "user_id", null: false
    t.text "notes"
    t.string "unit", default: "liters"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "product_id"
    t.index ["from_date", "to_date", "user_id"], name: "index_procurement_schedules_active", where: "((status)::text = 'active'::text)"
    t.index ["product_id", "status"], name: "index_procurement_schedules_on_product_and_status"
    t.index ["product_id"], name: "index_procurement_schedules_on_product_id"
    t.index ["user_id", "from_date", "to_date"], name: "index_procurement_schedules_on_user_and_dates"
    t.index ["user_id"], name: "index_procurement_schedules_on_user_id"
    t.index ["vendor_name", "status"], name: "index_procurement_schedules_on_vendor_and_status"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.string "unit_type"
    t.decimal "available_quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_gst_applicable", default: false
    t.decimal "total_gst_percentage", precision: 5, scale: 2
    t.decimal "total_cgst_percentage", precision: 5, scale: 2
    t.decimal "total_sgst_percentage", precision: 5, scale: 2
    t.decimal "total_igst_percentage", precision: 5, scale: 2
    t.bigint "category_id"
    t.string "image_url"
    t.string "sku"
    t.integer "stock_alert_threshold"
    t.boolean "is_subscription_eligible", default: false
    t.boolean "is_active", default: true
    t.string "hsn_sac"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["is_active"], name: "index_products_on_is_active"
    t.index ["is_subscription_eligible"], name: "index_products_on_is_subscription_eligible"
    t.index ["name"], name: "index_products_on_name"
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "purchase_customers", force: :cascade do |t|
    t.string "name", null: false
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "phone_number", null: false
    t.string "email"
    t.string "gst_number"
    t.string "pan_number"
    t.string "contact_person"
    t.text "shipping_address"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gst_number"], name: "index_purchase_customers_on_gst_number"
    t.index ["is_active"], name: "index_purchase_customers_on_is_active"
    t.index ["name"], name: "index_purchase_customers_on_name", unique: true
  end

  create_table "purchase_invoice_items", force: :cascade do |t|
    t.bigint "purchase_invoice_id", null: false
    t.bigint "purchase_product_id", null: false
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "discount", precision: 10, scale: 2, default: "0.0"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.string "hsn_sac"
    t.index ["purchase_invoice_id", "purchase_product_id"], name: "index_purchase_items_on_invoice_and_product"
    t.index ["purchase_invoice_id"], name: "index_purchase_invoice_items_on_purchase_invoice_id"
    t.index ["purchase_product_id"], name: "index_purchase_invoice_items_on_purchase_product_id"
  end

  create_table "purchase_invoices", force: :cascade do |t|
    t.string "invoice_number", null: false
    t.string "party_name", null: false
    t.date "invoice_date", null: false
    t.date "due_date"
    t.integer "payment_terms", default: 30
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "amount_paid", precision: 10, scale: 2, default: "0.0"
    t.decimal "balance_amount", precision: 10, scale: 2, default: "0.0"
    t.string "status", default: "unpaid"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "original_invoice_number"
    t.text "bill_from"
    t.text "ship_from"
    t.decimal "additional_charges", precision: 10, scale: 2, default: "0.0"
    t.decimal "additional_discount", precision: 10, scale: 2, default: "0.0"
    t.boolean "auto_round_off", default: false
    t.decimal "round_off_amount", precision: 10, scale: 2, default: "0.0"
    t.string "payment_type", default: "cash"
    t.text "terms_and_conditions"
    t.text "authorized_signature"
    t.index ["invoice_number"], name: "index_purchase_invoices_on_invoice_number"
    t.index ["original_invoice_number"], name: "index_purchase_invoices_on_original_invoice_number"
    t.index ["party_name"], name: "index_purchase_invoices_on_party_name"
    t.index ["payment_type"], name: "index_purchase_invoices_on_payment_type"
    t.index ["status"], name: "index_purchase_invoices_on_status"
  end

  create_table "purchase_products", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.decimal "purchase_price", precision: 10, scale: 2
    t.decimal "sales_price", precision: 10, scale: 2
    t.string "measuring_unit", default: "PCS"
    t.integer "opening_stock", default: 0
    t.integer "current_stock", default: 0
    t.boolean "enable_serialization", default: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status"
    t.string "hsn_sac"
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.index ["category"], name: "index_purchase_products_on_category"
    t.index ["hsn_sac"], name: "index_purchase_products_on_hsn_sac"
    t.index ["name"], name: "index_purchase_products_on_name"
  end

  create_table "referral_codes", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "code", null: false
    t.integer "total_credits", default: 0, null: false
    t.integer "total_referrals", default: 0, null: false
    t.string "share_url_slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_referral_codes_on_code", unique: true
    t.index ["customer_id"], name: "index_referral_codes_on_customer_id", unique: true
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.string "token_hash", null: false
    t.string "replaced_by_token_hash"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.bigint "user_id"
    t.bigint "customer_id"
    t.string "user_agent"
    t.string "created_by_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_refresh_tokens_on_customer_id"
    t.index ["replaced_by_token_hash"], name: "index_refresh_tokens_on_replaced_by_token_hash"
    t.index ["token_hash"], name: "index_refresh_tokens_on_token_hash", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.string "name", null: false
    t.string "report_type", null: false
    t.date "from_date", null: false
    t.date "to_date", null: false
    t.bigint "user_id", null: false
    t.text "content"
    t.string "file_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_date", "to_date"], name: "index_reports_on_from_date_and_to_date"
    t.index ["report_type"], name: "index_reports_on_report_type"
    t.index ["user_id", "created_at"], name: "index_reports_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_reports_on_user_id"
  end

  create_table "sales_customers", force: :cascade do |t|
    t.string "name", null: false
    t.text "address"
    t.string "city"
    t.string "state"
    t.string "pincode"
    t.string "phone_number", null: false
    t.string "email"
    t.string "gst_number"
    t.string "pan_number"
    t.string "contact_person"
    t.text "shipping_address"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gst_number"], name: "index_sales_customers_on_gst_number"
    t.index ["is_active"], name: "index_sales_customers_on_is_active"
    t.index ["name"], name: "index_sales_customers_on_name", unique: true
  end

  create_table "sales_invoice_items", force: :cascade do |t|
    t.bigint "sales_invoice_id", null: false
    t.bigint "sales_product_id", null: false
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "discount", precision: 10, scale: 2, default: "0.0"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hsn_sac"
    t.string "item_type", default: "SalesProduct"
    t.bigint "product_id"
    t.index ["item_type", "product_id"], name: "index_sales_invoice_items_on_item_type_and_product_id"
    t.index ["item_type", "sales_product_id"], name: "index_sales_invoice_items_on_item_type_and_sales_product_id"
    t.index ["product_id"], name: "index_sales_invoice_items_on_product_id"
    t.index ["sales_invoice_id", "sales_product_id"], name: "index_sales_items_on_invoice_and_product"
    t.index ["sales_invoice_id"], name: "index_sales_invoice_items_on_sales_invoice_id"
    t.index ["sales_product_id"], name: "index_sales_invoice_items_on_sales_product_id"
  end

  create_table "sales_invoices", force: :cascade do |t|
    t.string "invoice_number", null: false
    t.string "invoice_type", null: false
    t.string "customer_name", null: false
    t.date "invoice_date", null: false
    t.date "due_date"
    t.integer "payment_terms", default: 30
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0"
    t.decimal "tax_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "discount_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "total_amount", precision: 10, scale: 2, default: "0.0"
    t.decimal "amount_paid", precision: 10, scale: 2, default: "0.0"
    t.decimal "balance_amount", precision: 10, scale: 2, default: "0.0"
    t.string "status", default: "pending"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "customer_id"
    t.text "bill_to"
    t.text "ship_to"
    t.decimal "additional_charges", precision: 10, scale: 2, default: "0.0"
    t.decimal "additional_discount", precision: 10, scale: 2, default: "0.0"
    t.boolean "apply_tcs", default: false
    t.decimal "tcs_rate", precision: 5, scale: 2, default: "0.0"
    t.boolean "auto_round_off", default: false
    t.decimal "round_off_amount", precision: 10, scale: 2, default: "0.0"
    t.string "payment_type", default: "cash"
    t.text "terms_and_conditions"
    t.text "authorized_signature"
    t.bigint "sales_customer_id"
    t.index ["customer_id"], name: "index_sales_invoices_on_customer_id"
    t.index ["customer_name"], name: "index_sales_invoices_on_customer_name"
    t.index ["invoice_number"], name: "index_sales_invoices_on_invoice_number"
    t.index ["invoice_type"], name: "index_sales_invoices_on_invoice_type"
    t.index ["sales_customer_id"], name: "index_sales_invoices_on_sales_customer_id"
    t.index ["status"], name: "index_sales_invoices_on_status"
  end

  create_table "sales_products", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.decimal "purchase_price", precision: 10, scale: 2
    t.decimal "sales_price", precision: 10, scale: 2
    t.string "measuring_unit", default: "PCS"
    t.integer "opening_stock", default: 0
    t.integer "current_stock", default: 0
    t.boolean "enable_serialization", default: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "hsn_sac"
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.index ["category"], name: "index_sales_products_on_category"
    t.index ["name"], name: "index_sales_products_on_name"
  end

  create_table "support_tickets", force: :cascade do |t|
    t.bigint "customer_id"
    t.string "subject"
    t.text "message", null: false
    t.string "channel", default: "app", null: false
    t.string "status", default: "open", null: false
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority"
    t.integer "assigned_to"
    t.datetime "resolved_at"
    t.integer "customer_rating"
    t.text "customer_feedback"
    t.index ["customer_id"], name: "index_support_tickets_on_customer_id"
    t.index ["status"], name: "index_support_tickets_on_status"
  end

  create_table "user_vacations", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.string "status", default: "active", null: false
    t.text "reason"
    t.datetime "paused_at"
    t.datetime "unpaused_at"
    t.datetime "cancelled_at"
    t.bigint "created_by"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by"], name: "index_user_vacations_on_created_by"
    t.index ["customer_id", "end_date"], name: "index_user_vacations_on_customer_id_and_end_date"
    t.index ["customer_id", "start_date"], name: "index_user_vacations_on_customer_id_and_start_date"
    t.index ["customer_id"], name: "index_user_vacations_on_customer_id"
    t.index ["status"], name: "index_user_vacations_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.string "password_digest"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "employee_id"
    t.index ["employee_id"], name: "index_users_on_employee_id", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "advertisements", "users"
  add_foreign_key "customer_addresses", "customers"
  add_foreign_key "customer_preferences", "customers"
  add_foreign_key "customers", "users"
  add_foreign_key "customers", "users", column: "delivery_person_id"
  add_foreign_key "deliveries", "customers"
  add_foreign_key "delivery_assignments", "customers"
  add_foreign_key "delivery_assignments", "delivery_schedules"
  add_foreign_key "delivery_assignments", "invoices"
  add_foreign_key "delivery_assignments", "products"
  add_foreign_key "delivery_assignments", "users"
  add_foreign_key "delivery_items", "deliveries"
  add_foreign_key "delivery_items", "products"
  add_foreign_key "delivery_schedules", "customers"
  add_foreign_key "delivery_schedules", "products"
  add_foreign_key "delivery_schedules", "users"
  add_foreign_key "faqs", "customers"
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoice_items", "products"
  add_foreign_key "invoices", "customers"
  add_foreign_key "parties", "users"
  add_foreign_key "procurement_assignments", "procurement_schedules"
  add_foreign_key "procurement_assignments", "products"
  add_foreign_key "procurement_assignments", "users"
  add_foreign_key "procurement_schedules", "products"
  add_foreign_key "procurement_schedules", "users"
  add_foreign_key "products", "categories"
  add_foreign_key "purchase_invoice_items", "purchase_invoices"
  add_foreign_key "purchase_invoice_items", "purchase_products"
  add_foreign_key "referral_codes", "customers"
  add_foreign_key "refresh_tokens", "customers"
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "reports", "users"
  add_foreign_key "sales_invoice_items", "products"
  add_foreign_key "sales_invoices", "customers"
  add_foreign_key "sales_invoices", "sales_customers"
  add_foreign_key "support_tickets", "customers"
  add_foreign_key "user_vacations", "customers"
end
