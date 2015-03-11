class MajesticStats
  include Sidekiq::Worker
  sidekiq_options :queue => :verify_domains
  
  def perform(page_id)
    puts 'majestic perform on perform'
    page = Page.using(:main_shard).find(page_id)
    
    m = MajesticSeo::Api::Client.new(api_key: ENV['majestic_api_key'], environment: ENV['majestic_env'])
    res = m.get_index_item_info([page.simple_url])
    
    res.items.each do |r|
      puts "majestic block perform #{r.response['CitationFlow']}"
      Page.using(:main_shard).update(page.id, citationflow: r.response['CitationFlow'].to_f, trustflow: r.response['TrustFlow'].to_f, trustmetric: r.response['TrustMetric'].to_f, refdomains: r.response['RefDomains'].to_i, backlinks: r.response['ExtBackLinks'].to_i)
    end
    
  end
  
  def on_complete(status, options)
    batch = VerifyMajesticBatch.where(batch_id: "#{options['bid']}").first
    if !batch.nil?
      batch.update(status: 'finished')
      puts 'finished verifying all majestic domains'
    end
  end
  
  def self.start(page_id)
    puts 'majestic perform on perform'
    page = Page.find(page_id)
    
    m = MajesticSeo::Api::Client.new(api_key: ENV['majestic_api_key'], environment: ENV['majestic_env'])
    res = m.get_index_item_info([page.simple_url])
    
    res.items.each do |r|
      puts "majestic block perform #{r.response['CitationFlow']}"
      Page.update(page.id, citationflow: r.response['CitationFlow'].to_f, trustflow: r.response['TrustFlow'].to_f, trustmetric: r.response['TrustMetric'].to_f, refdomains: r.response['RefDomains'].to_i, backlinks: r.response['ExtBackLinks'].to_i)
    end
  end

  # def self.start(page_id)
  #   puts 'majestic start'
  #   page = Page.find(page_id)
  #   if page.site.verify_majestic_batch.nil?
  #     verify_majestic_batch = Sidekiq::Batch.new
  #     VerifyMajesticBatch.create(site_id: page.site.id, started_at: Time.now, status: "running", batch_id: verify_majestic_batch.bid)
  #     verify_majestic_batch.on(:complete, MajesticStats, 'bid' => verify_majestic_batch.bid)
  #   else
  #     verify_majestic_batch = Sidekiq::Batch.new(page.site.verify_majestic_batch.batch_id)
  #   end
  #
  #   verify_majestic_batch.jobs do
  #     puts 'majestic job batch'
  #     MajesticStats.perform_async(page.id)
  #   end
  # end
  
end