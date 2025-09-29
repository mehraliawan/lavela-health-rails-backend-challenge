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

ActiveRecord::Schema[8.0].define(version: 2025_09_29_143723) do
  create_table "appointments", force: :cascade do |t|
    t.integer "client_id", null: false
    t.integer "provider_id", null: false
    t.integer "availability_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.integer "duration_minutes", null: false
    t.string "status", default: "scheduled", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["availability_id", "starts_at", "ends_at"], name: "idx_on_availability_id_starts_at_ends_at_947f165e6a"
    t.index ["availability_id"], name: "index_appointments_on_availability_id"
    t.index ["client_id"], name: "index_appointments_on_client_id"
    t.index ["provider_id", "starts_at", "ends_at"], name: "index_appointments_on_provider_id_and_starts_at_and_ends_at"
    t.index ["provider_id"], name: "index_appointments_on_provider_id"
    t.index ["status"], name: "index_appointments_on_status"
  end

  create_table "availabilities", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "external_id", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.string "source", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_availabilities_on_external_id", unique: true
    t.index ["provider_id", "starts_at", "ends_at"], name: "index_availabilities_on_provider_id_and_starts_at_and_ends_at"
    t.index ["provider_id"], name: "index_availabilities_on_provider_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_clients_on_email", unique: true
  end

  create_table "providers", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_providers_on_email", unique: true
  end

  add_foreign_key "appointments", "availabilities"
  add_foreign_key "appointments", "clients"
  add_foreign_key "appointments", "providers"
  add_foreign_key "availabilities", "providers"
end
