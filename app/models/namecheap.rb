require 'domainatrix'
class Namecheap
  
  def self.check(site_id)
    site = Site.find(site_id)
    urls = Namecheap.urls_to_string(site_id)
    
    RestClient.proxy = 'http://proxy:d9495893e1a6-4792-b778-0e541a5d1370@proxy-174-129-240-180.proximo.io'
    res = RestClient.get("https://api.namecheap.com/xml.response?ApiUser=ENV['name_cheap_api_username']&ApiKey=ENV['name_cheap_api_key']&UserName=ENV['name_cheap_api_username']&ClientIp=ENV['name_cheap_client_ip']&Command=namecheap.domains.check&DomainList=#{urls}")
    hash = Hash.from_xml(res)
    hash["ApiResponse"]["CommandResponse"]["DomainCheckResult"].map do |r|
      page = site.pages.where("simple_url = ?", r['Domain']).first
      page = Page.update(page.id, verified: true, available: r['Available'])
    end
    Majestic.get_info(site_id)
    LinkScape.get_info(site_id)
  end
  
  def self.urls_to_string(site_id)
    site = Site.find(site_id)
    pages = site.pages.where(status_code: "0").to_a.uniq{|p| p.url}
    parsed_links = []
    pages.each do |p|
      url = Domainatrix.parse("#{p.url}")
      parsed_url = url.domain + "." + url.public_suffix
      parsed_links << parsed_url
      Page.update(p.id, simple_url: "#{parsed_url}")
    end
    urls_string = parsed_links.uniq.join(",")
  end
  
end