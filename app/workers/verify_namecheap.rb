require 'domainatrix'
require 'unirest'

class VerifyNamecheap
  include Sidekiq::Worker
  sidekiq_options :queue => :verify_domains
  
  def perform(page_id)
    page = Page.where(id: page_id).first
    
    begin
      if page
        url = Domainatrix.parse("#{page.url}")
        if !url.domain.empty? && !url.public_suffix.empty?
          puts "here is the parsed url #{page.url}"
          parsed_url = url.domain + "." + url.public_suffix
          unless page.site.pages.where("simple_url IS NOT NULL").map(&:simple_url).include?(parsed_url)
            puts "checking url #{parsed_url} on namecheap"
            uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/#{parsed_url}")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Get.new(uri.request_uri)
            request["X-Mashape-Key"] = "mPFRSsEZO6mshKl5Fyhvj8BxqunQp19PVM9jsntVJ4Q7Em4HkC"
            request["Accept"] = "application/json"
            response = http.request(request)
            json = JSON.parse(response.read_body)
            Page.update(page.id, simple_url: "#{parsed_url}", verified: true, available: "#{json['available']}")
            puts 'saving verified domain'
            if json['available'].to_s == 'true'
              puts 'Majestic & Moz stats being saved'
              crawl = page.site.crawl
              MozStats.perform_async(page.id)
              MajesticStats.perform_async(page.id)
              crawl.update(total_expired: craw.total_expired.to_i+1)
            end
          end
        end
      end
    rescue
      nil
    end
  end
  
  def on_complete(status, options)
    batch = VerifyNamecheapBatch.where(batch_id: "#{options['bid']}").first
    if !batch.nil?
      app = batch.site.crawl.heroku_app
      app.update(verified: 'finished') if app
      puts 'finished verifying all namecheap domains'
    end
  end
  
  
  def self.test
    uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/howimidoing.com")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    request["X-Mashape-Key"] = "mPFRSsEZO6mshKl5Fyhvj8BxqunQp19PVM9jsntVJ4Q7Em4HkC"
    request["Accept"] = "application/json"
    response = http.request(request)
    json = JSON.parse(response.read_body)
    json['available']
  end
  
end