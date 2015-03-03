web: bundle exec passenger start -p $PORT --max-pool-size 3
worker: bundle exec sidekiq -c 3
processlinks: bundle exec sidekiq -q process_links -c 3
sidekiqstats: bundle exec sidekiq -q sidekiq_stats -c 3
