class Page < ActiveRecord::Base
  belongs_to :site
  # after_create :verify_namecheap
  
  def verify_namecheap
    puts 'verifying namecheap'
    if status_code == '0' && internal == false
      site = Site.using(:main_shard).find(site_id)
      site_total_expired = site.total_expired.to_i + 1
      crawl_total_expired = site.crawl.total_expired.to_i + 1
      site.crawl.update(total_expired: crawl_total_expired)
      site.update(total_expired: site_total_expired)
      
      if site.verify_namecheap_batch.nil?
        verify_namecheap_batch = Sidekiq::Batch.new
        VerifyNamecheapBatch.create(site_id: site.id, started_at: Time.now, status: "running", batch_id: verify_namecheap_batch.bid)
        verify_namecheap_batch.on(:complete, VerifyNamecheap, 'bid' => verify_namecheap_batch.bid)
      else
        verify_namecheap_batch = Sidekiq::Batch.new(site.verify_namecheap_batch.batch_id)
      end
      
      verify_namecheap_batch.jobs do
        VerifyNamecheap.perform_async(id)
      end
      
    elsif status_code == '404'
      site = Site.using(:main_shard).find(site_id)
      site_total_broken = site.total_broken.to_i + 1
      crawl_total_broken = site.crawl.total_broken.to_i + 1
      site.crawl.update(total_broken: crawl_total_broken)
      site.update(total_broken: site_total_broken)
    end
  end
  
end
