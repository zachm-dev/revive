require 'domainatrix'
require 'unirest'

class VerifyNamecheap
  include Sidekiq::Worker
  sidekiq_options :queue => :verify_domains
  
  def self.perform(redis_id)

    # START OF VERIFY DOMAIN STATUS
  
    
    page_from_redis = $redis.get(redis_id)
    puts "the page from redis is #{page_from_redis}"
    if !page_from_redis.nil?
      page = JSON.parse(page_from_redis)
      puts "verify namecheap: the page object is #{page}"

      begin
        puts 'found page to verify namecheap'
        url = Domainatrix.parse("#{page['url']}")
        if !url.domain.empty? && !url.public_suffix.empty?
          puts "here is the parsed url #{page['url']}"
          parsed_url = url.domain + "." + url.public_suffix
          if !Rails.cache.read(["crawl/#{page['crawl_id']}/available"]).include?(parsed_url)
            puts "checking url #{parsed_url} on namecheap"
            uri = URI.parse("https://nametoolkit-name-toolkit.p.mashape.com/beta/whois/#{parsed_url}")
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            request = Net::HTTP::Get.new(uri.request_uri)
            request["X-Mashape-Key"] = "6CWhVxnwLhmshW8UaLSYUSlMocdqp1kkOR4jsnmEFj0MrrHB5T"
            request["Accept"] = "application/json"
            response = http.request(request)
            json = JSON.parse(response.read_body)
            puts "the domain verification response is #{json}"
            tlds = [".gov", ".edu"]
            if json['available'].to_s == 'true' && !Rails.cache.read(["crawl/#{page['crawl_id']}/available"]).include?("#{parsed_url}") && !tlds.any?{|tld| parsed_url.include?(tld)}         
              puts "saving verified domain with the following data processor_name: #{page['processor_name']}, status_code: #{page['status_code']}, url: #{page['url']}, internal: #{page['internal']}, site_id: #{page['site_id']}, found_on: #{page['found_on']}, simple_url: #{parsed_url}, verified: true, available: #{json['available']}, crawl_id: #{page['crawl_id']}"
              
              urls = Rails.cache.read(["crawl/#{page['crawl_id']}/available"])
              Rails.cache.write(["crawl/#{page['crawl_id']}/available"], urls.push("#{parsed_url}"))
              
              new_page = Page.using("#{page['processor_name']}").create(status_code: page['status_code'], url: page['url'], internal: page['internal'], site_id: page['site_id'].to_i, found_on: page['found_on'], simple_url: parsed_url, verified: true, available: "#{json['available']}", crawl_id: page['crawl_id'].to_i, redis_id: redis_id)
              puts "VerifyNamecheap: saved verified domain #{new_page.id}"

              Rails.cache.increment(["crawl/#{page['crawl_id']}/expired_domains"])
              Rails.cache.increment(["site/#{page['site_id']}/expired_domains"])
      
              page_hash = {}
      
              puts 'sync moz perform on perform'
              client = Linkscape::Client.new(:accessID => "member-8967f7dff3", :secret => "8b98d4acd435d50482ebeded953e2331")
              response = client.urlMetrics([parsed_url], :cols => :all)

              response.data.map do |r|
                begin
                  puts "moz block perform regular"
                  url = Domainatrix.parse("#{r[:uu]}")
                  parsed_url = url.domain + "." + url.public_suffix
                  # Page.using("#{processor_name}").update(page.id, da: r[:pda].to_f, pa: r[:upa].to_f)
                  page_hash[:da] = r[:pda].to_f
                  page_hash[:pa] = r[:upa].to_f
                  puts "moz updated page object #{page.da} #{page.pa}"
                rescue
                  puts "moz block perform zero"
                  page_hash[:da] = 0
                  page_hash[:pa] = 0
                  puts "moz updated page object #{page_hash}"
                  # Page.using("#{processor_name}").update(page.id, da: 0, pa: 0)
                end
              end
      
              puts 'finished checking moz sync'
      
              puts 'sync majestic perform on perform'
              m = MajesticSeo::Api::Client.new(api_key: ENV['majestic_api_key'], environment: ENV['majestic_env'])
              res = m.get_index_item_info([parsed_url])

              res.items.each do |r|
                puts "majestic block perform #{r.response['CitationFlow']}"
                page_hash[:citationflow] = r.response['CitationFlow'].to_f
                page_hash[:trustflow] = r.response['TrustFlow'].to_f
                page_hash[:trustmetric] = r.response['TrustMetric'].to_f
                page_hash[:refdomains] = r.response['RefDomains'].to_i
                page_hash[:backlinks] = r.response['ExtBackLinks'].to_i
        
              end
      
              puts 'finished checking majestic sync'
      
              puts "VerifyNamecheap about to save page #{page_hash}"
              Page.using("#{page['processor_name']}").update(new_page.id, page_hash)
              
              puts "verified and saved new domain calling to see if there are more to verify"
              Rails.cache.write(['domain_being_verified'], [])
              VerifyNamecheap.delay.start
              
            end
          end
        end
      rescue
        puts "VerifyNamecheap failed"
        Rails.cache.write(['domain_being_verified'], [])
        puts "VerifyNamecheap: calling start perform method "
        VerifyNamecheap.delay.start
      end
      
    else
      puts "VerifyNamecheap no page found on redis"
      Rails.cache.write(['domain_being_verified'], [])
      puts "VerifyNamecheap: calling start perform method else call"
      VerifyNamecheap.delay.start
    end
    
    # END OF VERIFY DOMAIN STATUS

  end
  
  def on_complete(status, options)
    puts "VerifyNamecheap: on_complete method"
    # expired_ids = Rails.cache.read(["crawl/#{options['crawl_id']}/expired_ids"]).to_a
    # puts "just finished verifying the domain and deleting from expired ids array #{expired_ids.include?(options['redis_id'])}"
    # expired_ids.delete(options['redis_id'])
    # puts "deleted the expired id from array #{!expired_ids.include?(options['redis_id'])}"
    # Rails.cache.write(["crawl/#{options['crawl_id']}/expired_ids"], expired_ids)
    puts "VerifyNamecheap: calling start on_complete "
    Rails.cache.write(['domain_being_verified'], [])
    VerifyNamecheap.delay.start
  end
  
  def self.start
    puts "VerifyNamecheap: start method"
    if Rails.cache.read(['domain_being_verified']).to_a.empty?
      puts "no domains currently being verified"
      expired_rotation = Rails.cache.read(['expired_rotation']).to_a
      if !expired_rotation.empty?
        puts "the current expired crawl rotation is #{expired_rotation}"
        next_crawl_to_process = expired_rotation[0]
        all_expired_ids = Rails.cache.read(["crawl/#{next_crawl_to_process}/expired_ids"]).to_a
        next_expired_id_to_verify = all_expired_ids[0]
        
        if !next_expired_id_to_verify.nil?
          puts "going to verify page #{next_expired_id_to_verify} for the crawl #{next_crawl_to_process}"
          Rails.cache.write(['domain_being_verified'], [next_expired_id_to_verify])
          puts "the domain to be verified is #{next_expired_id_to_verify}"
          new_expired_rotation = expired_rotation.rotate
          Rails.cache.write(['expired_rotation'], new_expired_rotation)
        
          new_expired_ids_rotation = all_expired_ids.rotate
          Rails.cache.write(["crawl/#{next_crawl_to_process}/expired_ids"], new_expired_ids_rotation)
        
          # batch = Sidekiq::Batch.new
          # batch.on(:complete, VerifyNamecheap, 'bid' => batch.bid, 'redis_id' => next_expired_id_to_verify, 'crawl_id' => next_crawl_to_process)
          # batch.jobs do
          #   puts "VerifyNamecheap: about to verify domain for crawl #{next_crawl_to_process} with id #{next_expired_id_to_verify}"
          #   VerifyNamecheap.perform_async(next_expired_id_to_verify)
          # end
          VerifyNamecheap.perform(next_expired_id_to_verify)
        
        else
          puts "there is a domain being verified #{Rails.cache.read(['domain_being_verified'])}"
          new_expired_rotation = expired_rotation.rotate
          Rails.cache.write(['expired_rotation'], new_expired_rotation)
          puts "VerifyNamecheap: calling start start method "
          # VerifyNamecheap.delay.start
        
        end
      end
    else
      puts "there is a domain being verified #{Rails.cache.read(['domain_being_verified'])}"
    end
  end

  
end