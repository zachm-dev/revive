class Majestic
  
  def self.get_info(site_id)
    site = Site.find(site_id)
    pages = site.pages.where(available: 'true').map(&:simple_url)
    m = MajesticSeo::Api::Client.new
    res = m.get_index_item_info(pages)
    
    res.items.map do |r|
      page = site.pages.where("simple_url = ?", r.response['Item']).first
      Page.update(page.id, citationflow: r.response['CitationFlow'], trustflow: r.response['TrustFlow'], trustmetric: r.response['TrustMetric'], refdomains: r.response['RefDomains'], backlinks: r.response['ExtBackLinks'])
    end
    
  end
  
end