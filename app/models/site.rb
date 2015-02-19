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
    sites = crawl.sites
    domains = sites.map(&:domain).each_slice(90)
    
    domains.map do |d|
      client = Linkscape::Client.new(:accessID => "ENV['linkscape_accessid']", :secret => "ENV['linkscape_secret']")
      response = client.urlMetrics(d, :cols => :all)
      
      response.data.map do |r|
        url = Domainatrix.parse("#{r[:uu]}")
        parsed_url = 'www.' + url.domain + "." + url.public_suffix

        site = Site.where("domain = ?", parsed_url).first
        if !site.nil?
          Site.update(site.id, da: r[:pda], pa: r[:upa])
        end
      end
    end
    
  end
  
  def self.save_majestic_data(options = {})
    crawl = Crawl.find(options[:crawl_id].to_i)
    sites = crawl.sites
    
    sites.each do |s|
      
    end
  end
  
end
