require 'domainatrix'

class Link < ActiveRecord::Base
  belongs_to :site
  has_one :process_links_batch
  # after_create :start_processing

  def self.start_processing(options={})

    puts "start_processing: start of method"
    
    stats = Sidekiq::Stats.new.queues["process_links"].to_i
    
    if stats < 500

      running_crawls = Rails.cache.read(['running_crawls']).to_a
      puts "start_processing: list of running crawls #{running_crawls}"
      if !running_crawls.empty?
        next_crawl_to_process = running_crawls[0]
        puts "next crawl to process #{next_crawl_to_process}"
        processing_link_ids = Rails.cache.read(["crawl/#{next_crawl_to_process}/processing_batches/ids"]).to_a[0]

        if !processing_link_ids.nil?
          puts "start_processing: there are more links to be processed"
          # next_link_id_to_process = processing_link_ids[0]
          puts "the next link to be processed is #{processing_link_ids}"
          new_crawls_rotation = running_crawls.rotate
      
          redis_obj = JSON.parse($redis.get(processing_link_ids))
          puts "start_processing: the redis obj is #{redis_obj}"
        
          Rails.cache.write(['running_crawls'], new_crawls_rotation)
          Rails.cache.write(['current_processing_batch_id'], "#{processing_link_ids}")
            
          processor_name = redis_obj['processor_name']
          site_id = redis_obj['site_id'].to_i
          crawl_id = redis_obj['crawl_id'].to_i
          base_url = redis_obj['base_url']
          crawl = Crawl.using("#{processor_name}").where(id: crawl_id).first
          domain = Domainatrix.parse(base_url).domain

          Rails.cache.increment(["crawl/#{crawl_id}/processing_batches/total"])
          Rails.cache.increment(["crawl/#{crawl_id}/processing_batches/running"])

          if Rails.cache.read(["site/#{site_id}/processing_batches/total"], raw: true).to_i == 0
            site = Site.using("#{processor_name}").where(id: site_id).first
            puts "updating site and creating new starting variables for processing batch for the site #{site_id}"
            site.update(processing_status: 'running')
            Rails.cache.write(["site/#{site_id}/processing_batches/total"], 1, raw: true)
            Rails.cache.write(["site/#{site_id}/processing_batches/running"], 1, raw: true)
            Rails.cache.write(["site/#{site_id}/processing_batches/finished"], 0, raw: true)
          else
            puts 'incrementing process batch stats'
            Rails.cache.increment(["site/#{site_id}/processing_batches/total"])
            Rails.cache.increment(["site/#{site_id}/processing_batches/running"])
          end
    
          puts " process links on complete variables link id #{processing_link_ids} site id #{site_id} and crawl id #{crawl_id}"
    
          batch = Sidekiq::Batch.new
          batch.on(:complete, ProcessLinks, 'bid' => batch.bid, 'crawl_id' => crawl_id, 'site_id' => site_id, 'redis_id' => processing_link_ids, 'user_id' => crawl.user_id, 'crawl_type' => crawl.crawl_type, 'iteration' => crawl.iteration.to_i, 'processor_name' => processor_name)
          
          Rails.cache.delete(processing_link_ids)
          
          batch.jobs do
            redis_obj['links'].each{|l| ProcessLinks.perform_async(l, site_id, redis_obj['found_on'], domain, crawl_id, 'processor_name' => processor_name)}
          end
        
        else
          if running_crawls.count > 1
            new_crawls_rotation = running_crawls.rotate
            Rails.cache.write(['running_crawls'], new_crawls_rotation)
            Link.delay.start_processing
          end 
        end

      end
    end
    
  end
  
end
