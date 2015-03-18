class Page < ActiveRecord::Base
  belongs_to :site
  after_create :verify_namecheap
  
  def verify_namecheap
    puts 'verifying namecheap'
    if status_code == '0' && internal == false
      site = Site.using(:processor).find(site_id)
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
      # site = Site.using(:processor).find(site_id)
      # site_total_broken = site.total_broken.to_i + 1
      # crawl_total_broken = site.crawl.total_broken.to_i + 1
      # site.crawl.update(total_broken: crawl_total_broken)
      # site.update(total_broken: site_total_broken)
      Rails.cache.increment(["crawl/#{crawl_id}/broken_domains"])
      Page.using(:processor).create(status_code: status_code, url: url, internal: internal, site_id: site_id, found_on: found_on, crawl_id: crawl_id)
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
