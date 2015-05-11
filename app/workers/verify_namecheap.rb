require 'domainatrix'
require 'unirest'

class VerifyNamecheap
  include Sidekiq::Worker
  sidekiq_options :queue => :verify_domains
  
  def self.verify(redis_id, crawl_id, options={})
    puts 'performing verify namecheap'
    processor_name = options['processor_name']
    # page = Page.using(:master).where(id: page_id).first
    
    page = JSON.parse($redis.get(redis_id))
    puts "verify namecheap: the page object is #{page}"
    
    begin
      if page.count > 0
        puts 'found page to verify namecheap'
        url = Domainatrix.parse("#{page['url']}")
        if !url.domain.empty? && !url.public_suffix.empty?
          puts "here is the parsed url #{page['url']}"
          parsed_url = url.domain + "." + url.public_suffix
          unless Page.using("#{processor_name}").where("simple_url IS NOT NULL AND site_id = ?", page['site_id'].to_i).map(&:simple_url).include?(parsed_url)
            puts "checking url #{parsed_url} on namecheap"
            uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/#{parsed_url}")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Get.new(uri.request_uri)
            request["X-Mashape-Key"] = "6CWhVxnwLhmshW8UaLSYUSlMocdqp1kkOR4jsnmEFj0MrrHB5T"
            request["Accept"] = "application/json"
            response = http.request(request)
            json = JSON.parse(response.read_body)
            tlds = [".gov", ".edu"]
            if json['available'].to_s == 'true' && !Rails.cache.read(["crawl/#{page['crawl_id']}/available"]).include?("#{parsed_url}") && !tlds.any?{|tld| parsed_url.include?(tld)}         
              puts "saving verified domain with the following data processor_name: #{processor_name}, status_code: #{page['status_code']}, url: #{page['url']}, internal: #{page['internal']}, site_id: #{page['site_id']}, found_on: #{page['found_on']}, simple_url: #{parsed_url}, verified: true, available: #{json['available']}, crawl_id: #{page['crawl_id']}"

              page = Page.using("#{processor_name}").create(status_code: page['status_code'], url: page['url'], internal: page['internal'], site_id: page['site_id'].to_i, found_on: page['found_on'], simple_url: parsed_url, verified: true, available: "#{json['available']}", crawl_id: page['crawl_id'].to_i, redis_id: redis_id)
              puts "VerifyNamecheap: saved verified domain #{page.id}"
              
              urls = Rails.cache.read(["crawl/#{page['crawl_id']}/available"])
              Rails.cache.write(["crawl/#{page['crawl_id']}/available"], urls.push("#{parsed_url}"))

              Rails.cache.increment(["crawl/#{page['crawl_id']}/expired_domains"])
              Rails.cache.increment(["site/#{page['site_id']}/expired_domains"])

              # MozStats.perform_async(redis_id, parsed_url, 'processor_name' => processor_name)
              # MajesticStats.perform_async(redis_id, parsed_url, 'processor_name' => processor_name)
              
              
              # MozStats.perform(page.id, parsed_url, 'processor_name' => options['processor_name'])
              # puts "MozStats synchronous for page #{page.id}"
              #
              # Page.get_id(redis_id, parsed_url, 'processor_name' => processor_name)
              
              
              puts 'sync moz perform on perform'
              client = Linkscape::Client.new(:accessID => "member-8967f7dff3", :secret => "8b98d4acd435d50482ebeded953e2331")
              response = client.urlMetrics([parsed_url], :cols => :all)
    
              response.data.map do |r|
                begin
                  puts "moz block perform regular"
                  url = Domainatrix.parse("#{r[:uu]}")
                  parsed_url = url.domain + "." + url.public_suffix
                  Page.using("#{processor_name}").update(page.id, da: r[:pda].to_f, pa: r[:upa].to_f)
                rescue
                  puts "moz block perform zero"
                  Page.using("#{processor_name}").update(page.id, da: 0, pa: 0)
                end
              end
              
              puts 'finished checking moz sync'
              
              puts 'sync majestic perform on perform'
              m = MajesticSeo::Api::Client.new(api_key: ENV['majestic_api_key'], environment: ENV['majestic_env'])
              res = m.get_index_item_info([parsed_url])
    
              res.items.each do |r|
                puts "majestic block perform #{r.response['CitationFlow']}"
                Page.using("#{processor_name}").update(page_id, citationflow: r.response['CitationFlow'].to_f, trustflow: r.response['TrustFlow'].to_f, trustmetric: r.response['TrustMetric'].to_f, refdomains: r.response['RefDomains'].to_i, backlinks: r.response['ExtBackLinks'].to_i)
              end
              
              puts 'finished checking majestic sync'
              
            end
          end
        end
      end
    rescue
      nil
    end
  end

  def perform(redis_id, crawl_id, options={})
    puts 'performing verify namecheap'
    processor_name = options['processor_name']
    # page = Page.using(:master).where(id: page_id).first
    
    page = JSON.parse($redis.get(redis_id))
    puts "verify namecheap: the page object is #{page}"
    
    begin
      if page.count > 0
        puts 'found page to verify namecheap'
        url = Domainatrix.parse("#{page['url']}")
        if !url.domain.empty? && !url.public_suffix.empty?
          puts "here is the parsed url #{page['url']}"
          parsed_url = url.domain + "." + url.public_suffix
          unless Page.using("#{processor_name}").where("simple_url IS NOT NULL AND site_id = ?", page['site_id'].to_i).map(&:simple_url).include?(parsed_url)
            puts "checking url #{parsed_url} on namecheap"
            uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/#{parsed_url}")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Get.new(uri.request_uri)
            request["X-Mashape-Key"] = "6CWhVxnwLhmshW8UaLSYUSlMocdqp1kkOR4jsnmEFj0MrrHB5T"
            request["Accept"] = "application/json"
            response = http.request(request)
            json = JSON.parse(response.read_body)
            tlds = [".gov", ".edu"]
            if json['available'].to_s == 'true' && !Rails.cache.read(["crawl/#{page['crawl_id']}/available"]).include?("#{parsed_url}") && !tlds.any?{|tld| parsed_url.include?(tld)}         
              puts "saving verified domain with the following data processor_name: #{processor_name}, status_code: #{page['status_code']}, url: #{page['url']}, internal: #{page['internal']}, site_id: #{page['site_id']}, found_on: #{page['found_on']}, simple_url: #{parsed_url}, verified: true, available: #{json['available']}, crawl_id: #{page['crawl_id']}"

              page = Page.using("#{processor_name}").create(status_code: page['status_code'], url: page['url'], internal: page['internal'], site_id: page['site_id'].to_i, found_on: page['found_on'], simple_url: parsed_url, verified: true, available: "#{json['available']}", crawl_id: page['crawl_id'].to_i, redis_id: redis_id)
              puts "VerifyNamecheap: saved verified domain #{page.id}"
              
              urls = Rails.cache.read(["crawl/#{page['crawl_id']}/available"])
              Rails.cache.write(["crawl/#{page['crawl_id']}/available"], urls.push("#{parsed_url}"))

              Rails.cache.increment(["crawl/#{page['crawl_id']}/expired_domains"])
              Rails.cache.increment(["site/#{page['site_id']}/expired_domains"])

              # MozStats.perform_async(redis_id, parsed_url, 'processor_name' => processor_name)
              # MajesticStats.perform_async(redis_id, parsed_url, 'processor_name' => processor_name)
              
              
              MozStats.perform(page.id, simple_url, 'processor_name' => options['processor_name'])
              puts "MozStats synchronous for page #{page.id}"
              
              Page.get_id(redis_id, parsed_url, 'processor_name' => processor_name)
              
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
      app = Site.using(:main_shard).find(batch.site_id).crawl.heroku_app
      app.update(verified: 'finished') if app
      puts 'finished verifying all namecheap domains'
    end
  end
  
  
  def self.test
    uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/howimidoing.com")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(uri.request_uri)
    request["X-Mashape-Key"] = "6CWhVxnwLhmshW8UaLSYUSlMocdqp1kkOR4jsnmEFj0MrrHB5T"
    request["Accept"] = "application/json"
    response = http.request(request)
    json = JSON.parse(response.read_body)
    json['available']
    return json
  end
  
end