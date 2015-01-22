require 'platform-api'

class Heroku
  attr_accessor :api_token, :app_name, :log_url
  
  APP_NAME = "ENV[:heroku_app_name]"
  API_TOKEN = "ENV[:heroku_app_name]"
  
  def self.client
    heroku = PlatformAPI.connect_oauth(API_TOKEN)
  end
  
  def self.formation_info(options = {})
    formation_type = options[:type].nil? ? "worker" : options[:type] 
    heroku = self.client
    formation = heroku.formation.info(APP_NAME, formation_type)
  end
  
  def self.formation_list
    heroku = self.client
    formation = heroku.formation.list(APP_NAME)
  end
  
  def self.get_dyno_stats
    formation = self.formation_info
    quantity = formation["quantity"]
    librato = DynoStats.new
    stats = {}
    quantity.times do |index|
      puts "worker.#{index+1}"
      memory_total = librato.metrics(metric: "memory_total", source: "worker.#{index+1}")
      resident_memory = librato.metrics(metric: "memory_rss", source: "worker.#{index+1}")
      swap_memory = librato.metrics(metric: "memory_swap", source: "worker.#{index+1}")
      stats["worker.#{index+1}".to_sym] = {memory_total: memory_total, resident_memory: resident_memory, swap_memory: swap_memory}
    end
    stats
  end
  
end