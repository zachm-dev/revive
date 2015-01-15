# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150113102543) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "crawls", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "links", force: :cascade do |t|
    t.integer  "site_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text     "links",                   array: true
  end

  create_table "pages", force: :cascade do |t|
    t.string   "status_code",      limit: 255
    t.string   "mime_type",        limit: 255
    t.string   "length",           limit: 255
    t.text     "links"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "headers"
    t.string   "crawl_id",         limit: 255
    t.text     "redirect_through"
    t.text     "url"
    t.integer  "site_id"
    t.boolean  "internal"
    t.text     "found_on"
  end

  create_table "sites", force: :cascade do |t|
    t.string   "base_url",   limit: 255
    t.integer  "crawl_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
