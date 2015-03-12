workers Integer(ENV['WEB_CONCURRENCY'] || 6)
threads_count = Integer(ENV['MAX_THREADS'] || 12)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # See: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
  ActiveRecord::Base.establish_connection
end


# #!/usr/bin/env puma
#
# # app do |env|
# #   puts env
# #
# #   body = 'Hello, World!'
# #
# #   [200, { 'Content-Type' => 'text/plain', 'Content-Length' => body.length.to_s }, [body]]
# # end
#
# environment 'production'
# daemonize false
#
# pidfile 'tmp/pids/puma.pid'
# state_path 'tmp/pids/puma.state'
#
# # stdout_redirect 'log/puma.log', 'log/puma_err.log'
#
# # quiet
# threads 0, 16
# bind 'unix://tmp/sockets/puma.sock'
#
# # ssl_bind '127.0.0.1', '9292', { key: path_to_key, cert: path_to_cert }
#
# # on_restart do
# #   puts 'On restart...'
# # end
#
# # restart_command '/u/app/lolcat/bin/restart_puma'
#
#
# # === Cluster mode ===
#
# # workers 2
#
# # on_worker_boot do
# #   puts 'On worker boot...'
# # end
#
# # === Puma control rack application ===
#
# activate_control_app 'unix://tmp/sockets/pumactl.sock'