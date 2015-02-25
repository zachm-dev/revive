source 'https://rubygems.org'

ruby "2.2.0"

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails'

# Use postgress as the database for Active Record
gem 'pg'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.3'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'


# Use jquery as the JavaScript library
gem 'jquery-rails' # $jQuery
gem 'jquery-ui-rails'# $jQuery UI

gem 'turbolinks' # AJAXED Page Gets

gem 'jbuilder', '~> 2.0' # Build JSON APIs with ease

# bundle exec rake doc:rails generates the API under doc/api.
gem 'sdoc', '~> 0.4.0',          group: :doc


gem 'bootstrap-sass', '~> 3.3.1'
gem 'autoprefixer-rails'
gem 'nokogiri'
gem 'slim'
gem 'lazy_high_charts'

gem 'sinatra', require: false
gem 'rubyretriever', github: 'darzuaga/rubyretriever', :branch => 'master'
gem 'domainatrix'
gem 'typhoeus'

# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.7'
gem 'rest-client'
gem 'faraday_middleware', :git => 'git://github.com/Agiley/faraday_middleware.git'
gem 'will_paginate', '~> 3.0.6'
gem 'will_paginate-bootstrap'
gem 'select2-rails'
gem 'unirest'
gem 'premailer-rails'
gem 'acts_as_list'

## Apis
gem 'stripe', :source => 'https://code.stripe.com/'
gem 'majestic_seo_api'
gem 'linkscape'
gem 'platform-api'
gem 'librato-metrics'



group :development do
  # Server Thing
  gem 'spring',  group: :development

  # Debuggers
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'pry'
  gem 'pry-byebug'
  gem 'awesome_print'
end

# Server Things
gem 'figaro' # Manage Secrets
gem 'thin' # Use Thin Server
gem 'passenger', '4.0.57'
gem 'foreman'

# If production use sidekiq pro url
if ENV['RACK_ENV'] == 'production'
  gem 'sidekiq-pro', :source => "https://#{ENV['sidekiq_url']}"
  gem 'rails_12factor', group: :production
else
  gem 'sidekiq-pro'
end

# Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
# gem 'polipus'
# gem 'hwacha'
#gem 'cobweb', github: 'darzuaga/cobweb', :branch => "passing-options-hash-to-page"
#gem 'sidekiq', :git => 'https://github.com/mperham/sidekiq.git'
#gem 'rubber'
#gem "puma"
#gem 'namecheap'
# gem 'sidekiq_monitor'
#gem 'newrelic_rpm'
#gem 'clockwork'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
# gem 'therubyracer',  platforms: :ruby






