class SidekiqLinks
  
  include Sidekiq::Worker
  sidekiq_options :queue => :sidekiq_links
  
  def perform
    
  end
  
  def on_complete(status, options)
    
  end
  
  def start
    
  end
  
end