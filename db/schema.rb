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

ActiveRecord::Schema.define(version: 20141230085609) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "crawls", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "pages", force: true do |t|
    t.string   "status_code"
    t.string   "mime_type"
    t.string   "length"
    t.text     "links"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "headers"
    t.string   "crawl_id"
    t.text     "redirect_through"
    t.text     "url"
  end

  create_table "sites", force: true do |t|
    t.string   "base_url"
    t.integer  "crawl_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

end
