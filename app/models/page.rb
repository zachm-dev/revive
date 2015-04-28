class Page < ActiveRecord::Base
  belongs_to :site
  after_create :verify_namecheap
  
  def self.verify_namecheap(options={})
    puts "verifying namecheap for crawl #{crawl_id}"
    
    redis_id = options['redis_id']
    redis_obj = JSON.parse($redis.get(redis_id))
    
    status_code = redis_obj['status_code ']
    internal = redis_obj['internal']
    crawl_id = redis_obj['crawl_id']
    processor_name = redis_obj['processor_name']
    site_id = redis_obj['site_id']
    
    if status_code == '0' && internal == false
      VerifyNamecheap.perform_async(redis_id, crawl_id, 'processor_name' => processor_name)
    elsif status_code == '404'
      Rails.cache.increment(["crawl/#{crawl_id}/broken_domains"])
      Rails.cache.increment(["site/#{site_id}/broken_domains"])
    end
  end

  def verify_namecheap
    puts 'verifying namecheap'
    if status_code == '0' && internal == false
      VerifyNamecheap.perform_async(id, crawl_id, 'processor_name' => processor_name)
    elsif status_code == '404'
      Rails.cache.increment(["crawl/#{crawl_id}/broken_domains"])
      Rails.cache.increment(["site/#{site_id}/broken_domains"])
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
