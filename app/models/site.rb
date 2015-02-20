require 'namecheap' 
require 'domainatrix'
class Site < ActiveRecord::Base
  belongs_to :crawl
  has_many :pages
  has_many :links
  has_one :gather_links_batch
  has_one :process_links_batch
  has_one :verify_namecheap_batch
  has_one :verify_majestic_batch
  
  def self.save_url_domains(options = {})
    crawl = Crawl.find(options[:crawl_id].to_i)
    sites = crawl.sites
    sites.each do |s|
      url = Domainatrix.parse(s.base_url)
      parsed_url = 'www.' + url.domain + "." + url.public_suffix
      Site.update(s.id, domain: parsed_url)
    end
  end
  
  def self.save_moz_data(options = {})
    crawl = Crawl.find(options[:crawl_id].to_i)
    sites = crawl.sites.select('id, domain').each_slice(90)
    
    sites.each do |site_array|
      ids = site_array.map(&:id)
      domains = site_array.map(&:domain)
      client = Linkscape::Client.new(:accessID => "ENV['linkscape_accessid']", :secret => "ENV['linkscape_secret']")
      response = client.urlMetrics(domains, :cols => :all)
      
      ids.each do |id|
        response.data.each do |r|
          url = Domainatrix.parse("#{r[:uu]}")
          parsed_url = 'www.' + url.domain + "." + url.public_suffix
          site = Site.where(id: id, domain: parsed_url).first
          if !site.nil?
            Site.update(site.id, da: r[:pda].to_f, pa: r[:upa].to_f)
          end
        end
      end
          
    end
  end
  
  def self.save_majestic_data(options = {})
    crawl = Crawl.find(options[:crawl_id].to_i)
    sites = crawl.sites.map(&:domain).each_slice(90).to_a
    sites.map do |s|
      m = MajesticSeo::Api::Client.new
      res = m.get_index_item_info(s)
      res.items.map do |r|
        site = Site.where("domain = ?", r.response['Item']).first
        if !site.nil?
          Site.update(site.id, cf: r.response['CitationFlow'].to_f, tf: r.response['TrustFlow'].to_f)
        end
      end
    end
  end
  
  def self.in_the_top_x_percent(percent, crawl_id)
    crawl = Crawl.find(crawl_id)
    sites = crawl.sites.where('da IS NOT NULL')
    total_sites_count = sites.count
    
    top_x_percent_amount = (percent.to_f * total_sites_count.to_f / 100.to_f).to_i
    
    site_ids = sites.order(da: :desc).limit(top_x_percent_amount).map(&:id)
    
  end
  
end
