require 'domainatrix'

class Link < ActiveRecord::Base
  belongs_to :site
  has_one :process_links_batch
  after_create :start_processing

  def self.start_processing(options={})

    puts "start_processing: start of method"

    running_crawls = Rails.cache.read(['running_crawls']).to_a
    puts "start_processing: list of running crawls #{running_crawls}"
    if !running_crawls.empty?
      next_crawl_to_process = running_crawls[0]
      next_link_id_to_process = Rails.cache.read(["crawl/#{next_crawl_to_process}/processing_batches/ids"]).to_a[0]

      if !next_link_id_to_process.nil?
        puts "start_processing: there are more links to be processed"
        puts "the next link to be processed is #{next_link_id_to_process}"
        new_crawls_rotation = running_crawls.rotate
        
        Rails.cache.write(["crawl/#{next_crawl_to_process}/processing_batches/ids"], processing_link_ids-[next_link_id_to_process])
        Rails.cache.write(['running_crawls'], new_crawls_rotation)
        Rails.cache.write(['current_processing_batch_id'], "#{next_link_id_to_process}")
      
      
        redis_obj = JSON.parse($redis.get(next_link_id_to_process))
        puts "start_processing: the redis obj is #{redis_obj}"
      
        processor_name = redis_obj['processor_name']
        redis_id = next_link_id_to_process
    
        puts 'starting processing method'
        site = Site.using("#{processor_name}").find(redis_obj['site_id'].to_i)
        crawl = site.crawl
        domain = Domainatrix.parse(site.base_url).domain

        Rails.cache.increment(["crawl/#{site.crawl_id}/processing_batches/total"])
        Rails.cache.increment(["crawl/#{site.crawl_id}/processing_batches/running"])

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
    
        puts "process links on complete variables link id #{redis_id} site id #{site.id} and crawl id #{site.crawl_id}"
    
        batch = Sidekiq::Batch.new
        # batch.on(:complete, ProcessLinks, 'bid' => batch.bid, 'crawl_id' => site.crawl_id, 'site_id' => site.id, 'link_id' => id, 'user_id' => crawl.user_id, 'crawl_type' => crawl.crawl_type, 'iteration' => crawl.iteration.to_i, 'processor_name' => processor_name)
    
        batch.on(:complete, ProcessLinks, 'bid' => batch.bid, 'crawl_id' => site.crawl_id, 'site_id' => site.id, 'redis_id' => redis_id, 'user_id' => crawl.user_id, 'crawl_type' => crawl.crawl_type, 'iteration' => crawl.iteration.to_i, 'processor_name' => processor_name)
    
        batch.jobs do
          # links.each{|l| ProcessLinks.perform_async(l, site.id, found_on, domain, site.crawl_id, 'processor_name' => processor_name)}
          redis_obj['links'].each{|l| ProcessLinks.perform_async(l, site.id, redis_obj['found_on'], domain, site.crawl_id, 'processor_name' => processor_name)}
        end
        
      else
        
        new_crawls_rotation = running_crawls.rotate
        Rails.cache.write(["crawl/#{next_crawl_to_process}/processing_batches/ids"], processing_link_ids-[next_link_id_to_process])
        Rails.cache.write(['running_crawls'], new_crawls_rotation)
        
      end

    end
  end
  
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
