require 'domainatrix'

class Link < ActiveRecord::Base
  belongs_to :site
  has_one :process_links_batch
  after_create :start_processing
  
  private
    
  def start_processing
    if process == true
      
      site = Site.using(:main_shard).find(site_id)
      domain = Domainatrix.parse(site.base_url).domain
      ids = Rails.cache.read(["crawl/#{site.crawl_id}/processing_batches/ids"])
      
      Rails.cache.increment(["crawl/#{site.crawl_id}/processing_batches/total"])
      Rails.cache.increment(["crawl/#{site.crawl_id}/processing_batches/running"])
      Rails.cache.write(["crawl/#{site.crawl_id}/processing_batches/ids"], ids<<id)
      
      if Rails.cache.read(["site/#{site_id}/processing_batches/total"], raw: true).nil?
        site.update(processing_status: 'running')
        Rails.cache.write(["site/#{site_id}/processing_batches/total"], 1, raw: true)
        Rails.cache.write(["site/#{site_id}/processing_batches/running"], 1, raw: true)
        Rails.cache.write(["site/#{site_id}/processing_batches/finished"], 0, raw: true)
      else
        Rails.cache.increment(["site/#{site_id}/processing_batches/total"])
        Rails.cache.increment(["site/#{site_id}/processing_batches/running"])
      end
      
      batch = Sidekiq::Batch.new
      batch.on(:complete, ProcessLinks, 'bid' => batch.bid, 'link_id' => 'id', 'site_id' => site.id, 'crawl_id' => site.crawl_id)
      
      batch.jobs do
        links.each{|l| ProcessLinks.perform_async(l, site_id, found_on, domain)}
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
