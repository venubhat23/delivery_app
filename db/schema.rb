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

ActiveRecord::Schema[8.0].define(version: 2025_07_24_173805) do
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
    t.index ["delivery_person_id"], name: "index_customers_on_delivery_person_id"
    t.index ["is_active"], name: "index_customers_on_is_active"
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
    t.index ["customer_id"], name: "index_delivery_assignments_on_customer_id"
    t.index ["delivery_schedule_id"], name: "index_delivery_assignments_on_delivery_schedule_id"
    t.index ["invoice_generated"], name: "index_delivery_assignments_on_invoice_generated"
    t.index ["invoice_id"], name: "index_delivery_assignments_on_invoice_id"
    t.index ["product_id"], name: "index_delivery_assignments_on_product_id"
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
    t.index ["customer_id"], name: "index_delivery_schedules_on_customer_id"
    t.index ["delivery_person_id"], name: "index_delivery_schedules_on_delivery_person_id"
    t.index ["product_id"], name: "index_delivery_schedules_on_product_id"
    t.index ["user_id"], name: "index_delivery_schedules_on_user_id"
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
    t.index ["customer_id"], name: "index_invoices_on_customer_id"
    t.index ["due_date"], name: "index_invoices_on_due_date"
    t.index ["invoice_date"], name: "index_invoices_on_invoice_date"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["invoice_type"], name: "index_invoices_on_invoice_type"
    t.index ["status"], name: "index_invoices_on_status"
  end

  create_table "milk_products", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["is_active"], name: "index_products_on_is_active"
    t.index ["is_subscription_eligible"], name: "index_products_on_is_subscription_eligible"
    t.index ["sku"], name: "index_products_on_sku", unique: true
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
    t.index ["purchase_invoice_id", "purchase_product_id"], name: "index_purchase_items_on_invoice_and_product"
    t.index ["purchase_invoice_id"], name: "index_purchase_invoice_items_on_purchase_invoice_id"
    t.index ["purchase_product_id"], name: "index_purchase_invoice_items_on_purchase_product_id"
  end

  create_table "purchase_invoices", force: :cascade do |t|
    t.string "invoice_number", null: false
    t.string "invoice_type", null: false
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
    t.index ["invoice_number"], name: "index_purchase_invoices_on_invoice_number"
    t.index ["invoice_type"], name: "index_purchase_invoices_on_invoice_type"
    t.index ["party_name"], name: "index_purchase_invoices_on_party_name"
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
    t.index ["category"], name: "index_purchase_products_on_category"
    t.index ["name"], name: "index_purchase_products_on_name"
    t.index ["status"], name: "index_purchase_products_on_status"
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
    t.index ["customer_id"], name: "index_sales_invoices_on_customer_id"
    t.index ["customer_name"], name: "index_sales_invoices_on_customer_name"
    t.index ["invoice_number"], name: "index_sales_invoices_on_invoice_number"
    t.index ["invoice_type"], name: "index_sales_invoices_on_invoice_type"
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

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.string "password_digest"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role"], name: "index_users_on_role"
  end

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
  add_foreign_key "invoice_items", "invoices"
  add_foreign_key "invoice_items", "products"
  add_foreign_key "invoices", "customers"
  add_foreign_key "products", "categories"
  add_foreign_key "purchase_invoice_items", "purchase_invoices"
  add_foreign_key "purchase_invoice_items", "purchase_products"
  add_foreign_key "sales_invoices", "customers"
end
