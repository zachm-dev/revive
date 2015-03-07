web: bundle exec passenger start -p $PORT --max-pool-size 3
worker: bundle exec sidekiq
processlinks: bundle exec sidekiq -q process_links
