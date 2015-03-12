web: bundle exec passenger start -p $PORT --max-pool-size 10
worker: bundle exec sidekiq
processlinks: bundle exec sidekiq -q process_links
verifydomains: bundle exec sidekiq -q verify_domains
