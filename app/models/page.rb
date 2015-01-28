class Page < ActiveRecord::Base
  belongs_to :site
  after_create :verify_namecheap
  
  def verify_namecheap
    if status_code == '0' && internal == false
      
      site = Site.find(site_id)
      
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
      
    end
  end
  
end
