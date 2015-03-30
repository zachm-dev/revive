require 'domainatrix'

class Link < ActiveRecord::Base
  belongs_to :site
  has_one :process_links_batch
  after_create :start_processing
  
  private
    
  def start_processing
    if process == true
      puts 'starting processing method'
      site = Site.using("#{processor_name}").find(site_id)
      crawl = site.crawl
      domain = Domainatrix.parse(site.base_url).domain
      ids = Rails.cache.read(["crawl/#{site.crawl_id}/processing_batches/ids"])

      total_processed = Rails.cache.increment(["crawl/#{site.crawl_id}/processing_batches/total"])
      Rails.cache.increment(["crawl/#{site.crawl_id}/processing_batches/running"])
      Rails.cache.write(["crawl/#{site.crawl_id}/processing_batches/ids"], ids<<id)

      if Rails.cache.read(["site/#{site.id}/processing_batches/total"], raw: true).to_i == 0
        
        puts "updating site and creating new starting variables for processing batch for the site #{site.id}"
        site.update(processing_status: 'running')
        Rails.cache.write(["site/#{site.id}/processing_batches/total"], 1, raw: true)
        Rails.cache.write(["site/#{site.id}/processing_batches/running"], 1, raw: true)
        Rails.cache.write(["site/#{site.id}/processing_batches/finished"], 0, raw: true)
      else
        puts 'incrementing process batch stats'
        Rails.cache.increment(["site/#{site.id}/processing_batches/total"])
        Rails.cache.increment(["site/#{site.id}/processing_batches/running"])
      end
      
      puts "process links on complete variables link id #{id} site id #{site.id} and crawl id #{site.crawl_id}"
      
      batch = Sidekiq::Batch.new
      batch.on(:complete, ProcessLinks, 'bid' => batch.bid, 'crawl_id' => site.crawl_id, 'site_id' => site.id, 'link_id' => id, 'user_id' => crawl.user_id, 'crawl_type' => crawl.crawl_type, 'iteration' => crawl.iteration.to_i, 'processor_name' => processor_name)
      
      batch.jobs do
        links.each{|l| ProcessLinks.perform_async(l, site.id, found_on, domain, site.crawl_id, 'processor_name' => processor_name)}
      end
      
    end
  end
  
  # def start_processing
  #
  #   if process == true
  #     site = Site.using(:main_shard).find(site_id)
  #     crawl = site.crawl
  #     domain = Domainatrix.parse(site.base_url).domain
  #
  #     if site.process_links_batch.nil?
  #       process_links_batch = Sidekiq::Batch.new
  #       site.update(processing_status: 'running')
  #       ProcessLinksBatch.create(site_id: site.id, started_at: Time.now, status: "running", batch_id: process_links_batch.bid, crawl_id: crawl.id)
  #       process_links_batch.on(:complete, ProcessLinks, 'bid' => process_links_batch.bid)
  #     else
  #       process_links_batch = Sidekiq::Batch.new(site.process_links_batch.batch_id)
  #     end
  #
  #     process_links_batch.jobs do
  #       links.each do |l|
  #         ProcessLinks.perform_async(l, site.id, found_on, domain)
  #       end
  #     end
  #   end
  #
  # end
  
end
