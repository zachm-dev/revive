redis: redis-server /usr/local/etc/redis.conf
sidekiq: bundle exec sidekiq -q crawl_worker, crawler_worker, default -c 100
web: bundle exec passenger start -p $PORT --max-pool-size 3