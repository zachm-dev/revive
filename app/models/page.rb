class Page < ActiveRecord::Base
  belongs_to :site
  after_create :verify_namecheap
  
  def verify_namecheap
    puts 'verifying namecheap'
    if status_code == '0' && internal == false
      # site = Site.using(:processor).find(site_id)
      # if site.verify_namecheap_batch.nil?
      #   verify_namecheap_batch = Sidekiq::Batch.new
      #   VerifyNamecheapBatch.create(site_id: site.id, started_at: Time.now, status: "running", batch_id: verify_namecheap_batch.bid)
      #   verify_namecheap_batch.on(:complete, VerifyNamecheap, 'bid' => verify_namecheap_batch.bid)
      # else
      #   verify_namecheap_batch = Sidekiq::Batch.new(site.verify_namecheap_batch.batch_id)
      # end
      #
      # verify_namecheap_batch.jobs do
      #   VerifyNamecheap.perform_async(id)
      # end
      
      VerifyNamecheap.perform_async(id, crawl_id)
      
    elsif status_code == '404'
      Rails.cache.increment(["crawl/#{crawl_id}/broken_domains"])
    end
  end
  
  def self.to_csv
    attributes = %w[simple_url da pa trustflow citationflow refdomains backlinks found_on]
    CSV.generate(headers: true) do |csv|
      csv << attributes
      
      all.each do |page|
        csv << page.attributes.values_at(*attributes)
      end
    end
  end
  
end
