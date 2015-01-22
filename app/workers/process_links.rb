require 'domainatrix'

class ProcessLinks
  
  include Sidekiq::Worker
  
  def perform(l, site_id, found_on, domain)
    request = Typhoeus::Request.new(l, method: :head, followlocation: true)
    request.on_complete do |response|
      internal = l.include?("#{domain}") ? true : false
      internal = true
      Page.delay.create(status_code: "#{response.code}", url: "#{l}", internal: internal, site_id: site_id, found_on: "#{found_on}")
    end
    request.run
  end
  
  def on_complete(status, options)
    #product = Product.find(options['pid'])
    #product.mark_visible!
    puts "ProcessLinks Just finished Batch #{options['bid']}"
  end
  
  def self.start(link_id)
    link = Link.find(link_id)
    links = link.links
    site = Site.find(link.site_id)
    #hydra = Typhoeus::Hydra.new
    domain = Domainatrix.parse(site.base_url).domain
    batch = Sidekiq::Batch.new
    batch.on(:complete, ProcessLinks, 'bid' => batch.bid)
    
    batch.jobs do
      links.each { |l| ProcessLinks.perform_async(l, site.id, link.found_on, domain) }
    end
  end
  
end