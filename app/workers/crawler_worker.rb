class CrawlerWorker
  include Sidekiq::Worker
  
  sidekiq_options queue: :crawler_worker
  
  def self.perform(page)
      #content = HashUtil.deep_symbolize_keys(page)
      Page.create(url: "#{page[:url]}", status_code: "#{page[:status_code]}", mime_type: "#{page[:mime_type]}", length: "#{page[:length].to_s}", redirect_through: "#{page[:redirect_through]}", headers: "#{page[:headers]}", links: "#{page[:links]}", crawl_id: "#{page[:myoptions][:crawl_id]}")
      #Page.create(url: "#{page[:url]}", status_code: "#{page[:status_code]}")
      #puts "the page length is #{page[:length].to_s} and redirect is #{page[:redirect_through]}"
      #puts "the page object is #{content}"
  end
  
  def self.queue_size
    Sidekiq.redis do |conn|
      conn.llen("queue:#{get_sidekiq_options["queue"]}")
    end
  end
  
end