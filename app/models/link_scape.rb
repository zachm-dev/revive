require 'domainatrix'
class LinkScape
  
  def self.get_info(site_id)
    site = Site.find(site_id)
    parsed_urls = LinkScape.urls_to_array(site_id)
    
    client = Linkscape::Client.new(:accessID => "ENV['linkscape_accessid']", :secret => "ENV['linkscape_secret']")
    response = client.urlMetrics(parsed_urls, :cols => :all)
    
    response.data.map do |r|
      url = Domainatrix.parse("#{r[:uu]}")
      parsed_url = url.domain + "." + url.public_suffix
      page = site.pages.where("simple_url = ?", parsed_url).first
      Page.update(page.id, da: r[:pda], pa: r[:upa])
    end
    
  end
  
  def self.urls_to_array(site_id)
    site = Site.find(site_id)
    parsed_urls = []
    pages = site.pages.where(available: 'true').map(&:simple_url)
    pages.map do |p|
      parsed_urls << URI.encode("www.#{p}")
    end
    parsed_urls
  end
  
end