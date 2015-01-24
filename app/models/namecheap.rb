require 'domainatrix'
class Namecheap
  
  def self.check(options = {})
    
    if options[:crawl_id]
      class_name = "crawl"
      obj = Crawl.find(options[:crawl_id])
      urls = Namecheap.urls_to_string(crawl_id: options[:crawl_id])
    elsif options[:site_id]
      class_name = "site"
      obj = Site.find(options[:site_id])
      urls = Namecheap.urls_to_string(site_id: options[:site_id])
    else
      class_name = "none"
      urls = Namecheap.urls_to_string
    end
    
    if !urls.empty?
      RestClient.proxy = 'http://proxy:d9495893e1a6-4792-b778-0e541a5d1370@proxy-174-129-240-180.proximo.io'
      res = RestClient.get("https://api.namecheap.com/xml.response?ApiUser=ENV['name_cheap_api_username']&ApiKey=ENV['name_cheap_api_key']&UserName=ENV['name_cheap_api_username']&ClientIp=ENV['name_cheap_client_ip']&Command=namecheap.domains.check&DomainList=#{urls}")
      hash = Hash.from_xml(res)
      hash["ApiResponse"]["CommandResponse"]["DomainCheckResult"].map do |r|
        if obj
          page = obj.pages.where("simple_url = ?", r['Domain']).first
          Page.update(page.id, verified: true, available: r['Available'])
          Majestic.get_info(class_name: class_name, obj_id: obj.id)
          LinkScape.get_info(class_name: class_name, obj_id: obj.id)
        else
          page = Page.where("simple_url = ?", r['Domain']).first
          Page.update(page.id, verified: true, available: r['Available'])
          Majestic.get_info
          LinkScape.get_info
        end
      end
    end

  end
  
  def self.urls_to_string(options = {})
    
    if options[:crawl_id]
      obj = Crawl.find(options[:crawl_id])
      get_pages = obj.pages.where(status_code: "0", internal: false)
    elsif options[:site_id]
      obj = Site.find(options[:site_id])
      get_pages = obj.pages.where(status_code: "0", internal: false)
    else
      get_pages = Page.where(status_code: "0", internal: false)
    end
    
    if get_pages.count != 0
      pages = get_pages.to_a.uniq{|p| p.url}
      parsed_links = []
      pages.each do |p|
        url = Domainatrix.parse("#{p.url}")
        parsed_url = url.domain + "." + url.public_suffix
        parsed_links << parsed_url
        Page.update(p.id, simple_url: "#{parsed_url}")
      end
      urls_string = parsed_links.uniq.join(",")
      return urls_string
    else
      return ""
    end
    
  end
  
end