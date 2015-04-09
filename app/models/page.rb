class Page < ActiveRecord::Base
  belongs_to :site
  after_create :verify_namecheap
  
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
  
  def self.available_to_csv
    attributes = %w[simple_url da pa trustflow citationflow refdomains backlinks]
    CSV.generate(headers: true) do |csv|
      csv << attributes
      all.each do |page|
        csv << [page[1], page[2], page[3], page[4], page[5], page[6], page[7]]
      end
    end
  end
  
end
