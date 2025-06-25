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

ActiveRecord::Schema[8.0].define(version: 2025_06_22_065935) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["delivery_person_id"], name: "index_customers_on_delivery_person_id"
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
    t.index ["customer_id"], name: "index_delivery_schedules_on_customer_id"
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
end
