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

ActiveRecord::Schema.define(version: 20150225055431) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "crawls", force: :cascade do |t|
    t.string   "name",                limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "maxpages"
    t.integer  "user_id"
    t.text     "app_url"
    t.string   "app_name"
    t.integer  "total_urls_found"
    t.integer  "total_pages_crawled"
    t.integer  "total_expired"
    t.integer  "total_broken"
    t.integer  "total_sites"
    t.integer  "total_internal"
    t.integer  "total_external"
    t.integer  "moz_da"
    t.integer  "majestic_tf"
    t.integer  "notify_me_after"
    t.string   "keyword"
  end

  create_table "expired_links", force: :cascade do |t|
    t.string   "url"
    t.string   "available"
    t.text     "site_i"
    t.integer  "site_id"
    t.boolean  "internal"
    t.text     "found_on"
    t.text     "simple_url"
    t.string   "citationflow"
    t.string   "trustflow"
    t.string   "trustmetric"
    t.string   "refdomains"
    t.string   "backlinks"
    t.string   "pa"
    t.string   "da"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  create_table "gather_links_batches", force: :cascade do |t|
    t.integer  "site_id"
    t.string   "status"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "batch_id"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.string   "pages_per_second"
    t.string   "est_crawl_time"
    t.string   "total_links_gathered"
  end

  create_table "heroku_apps", force: :cascade do |t|
    t.string   "name"
    t.text     "url"
    t.integer  "crawl_id"
    t.string   "status"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "batch_id"
    t.string   "verified"
    t.integer  "pos"
    t.integer  "position"
    t.boolean  "shutdown"
  end

  create_table "links", force: :cascade do |t|
    t.integer  "site_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text     "links",                   array: true
    t.text     "found_on"
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
    t.boolean  "verified"
    t.text     "simple_url"
    t.string   "available"
    t.string   "citationflow"
    t.string   "trustflow"
    t.string   "trustmetric"
    t.string   "refdomains"
    t.string   "backlinks"
    t.string   "pa"
    t.string   "da"
    t.string   "status"
  end

  create_table "plans", force: :cascade do |t|
    t.string   "name"
    t.integer  "pages_per_crawl"
    t.integer  "expired_domains"
    t.integer  "broken_domains"
    t.integer  "crawls_at_the_same_time"
    t.integer  "reserve_period"
    t.integer  "crawl_speed"
    t.boolean  "marketplace"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.float    "price"
  end

  create_table "process_links_batches", force: :cascade do |t|
    t.integer  "site_id"
    t.string   "status"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "batch_id"
    t.string   "pages_per_second"
    t.string   "est_crawl_time"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.integer  "link_id"
  end

  create_table "sidekiq_jobs", force: :cascade do |t|
    t.string   "jid"
    t.string   "queue"
    t.string   "class_name"
    t.text     "args"
    t.boolean  "retry"
    t.datetime "enqueued_at"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "status"
    t.string   "name"
    t.text     "result"
  end

  add_index "sidekiq_jobs", ["class_name"], name: "index_sidekiq_jobs_on_class_name", using: :btree
  add_index "sidekiq_jobs", ["enqueued_at"], name: "index_sidekiq_jobs_on_enqueued_at", using: :btree
  add_index "sidekiq_jobs", ["finished_at"], name: "index_sidekiq_jobs_on_finished_at", using: :btree
  add_index "sidekiq_jobs", ["jid"], name: "index_sidekiq_jobs_on_jid", using: :btree
  add_index "sidekiq_jobs", ["queue"], name: "index_sidekiq_jobs_on_queue", using: :btree
  add_index "sidekiq_jobs", ["retry"], name: "index_sidekiq_jobs_on_retry", using: :btree
  add_index "sidekiq_jobs", ["started_at"], name: "index_sidekiq_jobs_on_started_at", using: :btree
  add_index "sidekiq_jobs", ["status"], name: "index_sidekiq_jobs_on_status", using: :btree

  create_table "sidekiq_stats", force: :cascade do |t|
    t.integer  "workers_size"
    t.integer  "enqueued"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "try_count"
    t.integer  "processed"
    t.integer  "heroku_app_id"
  end

  create_table "sites", force: :cascade do |t|
    t.integer  "crawl_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "maxpages"
    t.boolean  "notified"
    t.text     "base_url"
    t.string   "domain"
    t.float    "da"
    t.float    "pa"
    t.float    "tf"
    t.float    "cf"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "stripe_customer_token"
    t.string   "status"
    t.integer  "plan_id"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.string   "plan_name"
  end

  create_table "user_dashboards", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "domains_crawled"
    t.integer  "domains_broken"
    t.integer  "domains_expired"
    t.integer  "pending_crawlers"
    t.integer  "running_crawlers"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.integer  "done_crawlers"
    t.text     "top_domains",      default: [],              array: true
  end

  add_index "user_dashboards", ["user_id"], name: "index_user_dashboards_on_user_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "email"
    t.string   "password_digest"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  create_table "verify_majestic_batches", force: :cascade do |t|
    t.integer  "site_id"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string   "batch_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  create_table "verify_namecheap_batches", force: :cascade do |t|
    t.integer  "page_id"
    t.string   "batch_id"
    t.string   "status"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.integer  "site_id"
  end

  add_foreign_key "user_dashboards", "users"
end
