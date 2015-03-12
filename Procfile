web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq
processlinks: bundle exec sidekiq -q process_links
verifydomains: bundle exec sidekiq -q verify_domains
