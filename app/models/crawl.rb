require 'retriever'
require 'domainatrix'

class Crawl < ActiveRecord::Base
  
  attr_accessor :hours, :minutes
  
  belongs_to :user
  has_many :sites
  has_many :pages, through: :sites
  has_many :links, through: :sites
  has_many :gather_links_batches, through: :sites
  has_many :process_links_batches, through: :sites
  has_one :heroku_app
  
  GOOGLE_PARAMS = ['links', 'resources', 'intitle:links', 'intitle:resources', 'intitle:sites', 'intitle:websites', 'inurl:links', 'inurl:resources', 'inurl:sites', 'inurl:websites', '"useful links"', '"useful resources"', '"useful sites"', '"useful websites"', '"recommended links"', '"recommended resources"', '"recommended sites"', '"recommended websites"', '"suggested links"', '"suggested resources"', '"suggested sites"', '"suggested websites"', '"more links"', '"more resources"', '"more sites"', '"more websites"', '"favorite links"', '"favorite resources"', '"favorite sites"', '"favorite websites"', '"related links"', '"related resources"', '"related sites"', '"related websites"', 'intitle:"useful links"', 'intitle:"useful resources"', 'intitle:"useful sites"', 'intitle:"useful websites"', 'intitle:"recommended links"', 'intitle:"recommended resources"', 'intitle:"recommended sites"', 'intitle:"recommended websites"', 'intitle:"suggested links"', 'intitle:"suggested resources"', 'intitle:"suggested sites"', 'intitle:"suggested websites"', 'intitle:"more links"', 'intitle:"more resources"', 'intitle:"more sites"', 'intitle:"more websites"', 'intitle:"favorite links"', 'intitle:"favorite resources"', 'intitle:"favorite sites"', 'intitle:"favorite websites"', 'intitle:"related links"', 'intitle:"related resources"', 'intitle:"related sites"', 'intitle:"related websites"', 'inurl:"useful links"', 'inurl:"useful resources"', 'inurl:"useful sites"', 'inurl:"useful websites"', 'inurl:"recommended links"', 'inurl:"recommended resources"', 'inurl:"recommended sites"', 'inurl:"recommended websites"', 'inurl:"suggested links"', 'inurl:"suggested resources"', 'inurl:"suggested sites"', 'inurl:"suggested websites"', 'inurl:"more links"', 'inurl:"more resources"', 'inurl:"more sites"', 'inurl:"more websites"', 'inurl:"favorite links"', 'inurl:"favorite resources"', 'inurl:"favorite sites"', 'inurl:"favorite websites"', 'inurl:"related links"', 'inurl:"related resources"', 'inurl:"related sites"', 'inurl:"related websites"', 'list of links', 'list of resources', 'list of sites', 'list of websites', 'list of blogs', 'list of forums']
  
  def self.stop_crawl(crawl_id, options={})
    puts "stop crawl method for the crawl #{crawl_id} in the processor #{options["processor_name"]}"
    processor_name = options["processor_name"]
    crawl = Crawl.using("#{processor_name}").where(id: crawl_id).first
    puts "here is the crawl to stop #{crawl.id} on the processor #{crawl.processor_name}"
    if crawl && crawl.status != 'finished'
      status = options['status'].nil? ? 'finished' : options['status']
      heroku_app = crawl.heroku_app
      
      if heroku_app
        heroku_app.update(status: status)
      end
      
      crawl.update(status: status)
      heroku = HerokuPlatform.new
      heroku.delete_app("revivecrawler#{crawl.id}")
      
    end
  end
  
  def self.start_crawl(options = {})
    processor_name = options['processor_name']
    puts "start_crawl: the processor name is #{processor_name}"
    crawl = Crawl.using("#{processor_name}").find(options["crawl_id"].to_i)
    puts "here is the crawl to start #{crawl.id} on the processor #{crawl.processor_name}"
    if crawl
      puts "crawl total minutes are #{crawl.total_minutes.to_i}"
      crawl.setCrawlStartingVariables('total_minutes' => crawl.total_minutes.to_i)
      if crawl.crawl_type == 'url_crawl'
        Crawl.save_new_sites(crawl.id, 'processor_name' => processor_name)
      elsif crawl.crawl_type == 'keyword_crawl'
        SaveSitesFromGoogle.start_batch(crawl.id, 'processor_name' => processor_name)
      end
    end
  end
  
  def setCrawlStartingVariables(options={})
    puts "setting crawl starting variables"
    
    Rails.cache.write(["crawl/#{self.id}/start_time"], Time.now, raw: true)
    Rails.cache.write(["crawl/#{self.id}/total_minutes_to_run"], options['total_minutes'].to_i, raw: true)
    
    Rails.cache.write(["crawl/#{self.id}/gathering_batches/total"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/gathering_batches/running"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/gathering_batches/finished"], 0, raw: true)

    Rails.cache.write(["crawl/#{self.id}/processing_batches/total"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/processing_batches/running"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/processing_batches/finished"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/processing_batches/ids"], [])
    Rails.cache.write(["crawl/#{self.id}/available"], [])
    
    # Rails.cache.write(["crawl/#{crawl.id}/connections/total_time"], 0, raw: true)
    # Rails.cache.write(["crawl/#{crawl.id}/connections/connect_time"], 0, raw: true)
    # Rails.cache.write(["crawl/#{crawl.id}/connections/total"], 0, raw: true)
    
    Rails.cache.write(["crawl/#{self.id}/urls_found"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/urls_crawled"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/expired_domains"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/broken_domains"], 0, raw: true)
    Rails.cache.write(["crawl/#{self.id}/progress"], 0.00, raw: true)
  end
  
  def self.decision_maker(options={})
    puts "making a decision #{options}"
    
    processor_name = options['processor_name']
    user = User.using(:main_shard).find(options['user_id'].to_i)
    plan = user.subscription.plan
    
    if user.minutes_used.to_f < 4500.to_f
      
      number_of_pending_crawls = Crawl.using("#{processor_name}").where(status: "pending", user_id: options['user_id'].to_i).count
      number_of_running_crawls = Crawl.using("#{processor_name}").where(status: "running", user_id: options['user_id'].to_i).count
      
      puts "the number of pending crawls is #{number_of_pending_crawls}"
      puts "the number of running crawls is #{number_of_running_crawls}"
      
      if number_of_running_crawls < plan.crawls_at_the_same_time
        if number_of_pending_crawls > 0
          number_of_apps_running = HerokuPlatform.new.app_list.count
          puts "the number of apps running are #{number_of_apps_running}"
          if number_of_apps_running < 99
            puts "decision: starting new crawl with the options #{options}"
            
            list_of_all_crawls = HerokuPlatform.new.app_list.map{|app| app['name']}.select{|obj| obj.include?('revivecrawler')}

            if !$redis.get('list_of_running_crawls').to_s.empty?
              list_of_running_crawls = JSON.parse($redis.get('list_of_running_crawls'))
              names_of_running_crawls = list_of_running_crawls.map{|crawl| crawl['name']}
              puts "list of names of the running crawls are #{names_of_running_crawls}" 
              
              available_crawls = ( (list_of_all_crawls | list_of_running_crawls) - list_of_running_crawls ).to_a
              puts "list of available crawls #{available_crawls}"
            
              if !available_crawls.empty?
                name = available_crawls[0]
                available_crawl_hash = {"name"=>name, "crawls"=>{"crawl_id"=>options['crawl_id'], "processor_name"=>processor_name}}
                updated_list_of_running_crawls = list_of_running_crawls.push(available_crawl_hash)
                puts "the updated list of running crawls is #{updated_list_of_running_crawls}"
                $redis.set('list_of_running_crawls', updated_list_of_running_crawls.to_json)
                
                Api.delay.start_crawl('app_name' => name, 'processor_name' => processor_name, 'crawl_id' => options['crawl_id'])
              end
            
            else
              puts "there is not a list of running crawls saved on redis"
              available_crawl_hash = {"name"=>'revivecrawler1', "crawls"=>{"crawl_id"=>options['crawl_id'], "processor_name"=>processor_name}}
              $redis.set('list_of_running_crawls', [available_crawl_hash].to_json)
              Api.delay.start_crawl('app_name' => name, 'processor_name' => processor_name, 'crawl_id' => options['crawl_id'])
            end
            
          end
        end
      else
        puts 'decision: exceeded crawls that can be performed at the same time'
      end
      
    end
  end
  
  def self.save_new_crawl(user_id, base_urls, options = {})
    
    user = User.using(:main_shard).find(user_id)
    plan = user.subscription.plan
    beta = true
    name = options[:name]
    moz_da = options[:moz_da].nil? ? nil : options[:moz_da].to_i
    majestic_tf = options[:majestic_tf].nil? ? nil : options[:majestic_tf].to_i
    notify_me_after = options[:notify_me_after].nil? ? nil : options[:notify_me_after].to_i
    total_crawl_minutes = ((options[:hours].to_i*60)+options[:minutes].to_i)
    puts "the total crawl minutes are #{total_crawl_minutes}"
    
    
    if beta == true
      if options[:maxpages].nil?
        maxpages = 10
      else
        maxpages = options[:maxpages].to_i > 500 ? 500 : options[:maxpages].to_i
      end
    else
      maxpages = options[:maxpages].empty? ? 10 : options[:maxpages].to_i
    end
    
    if base_urls.include?("\r\n")
      urls_array = base_urls.split(/[\r\n]+/).map(&:strip)
    else
      urls_array = base_urls.split(",")
    end
    
    processors_hash = {}
    processors_array = ['processor_three', 'processor_four', 'processor', 'processor_one', 'processor_two']
    processors_array.each do |processor_name|
      running_count = Crawl.using(processor_name).where(status: 'running').count
      processors_hash[processor_name] = running_count
    end
    processor_name = processors_hash.sort_by{|k,v|v}[0][0]
    
    new_crawl = Crawl.using("#{processor_name}").create(user_id: user_id, name: name, maxpages: maxpages, crawl_type: 'url_crawl', base_urls: urls_array, total_sites: urls_array.count.to_i, status: 'pending', max_pages_allowed: plan.pages_per_crawl.to_i, moz_da: moz_da, majestic_tf: majestic_tf, notify_me_after: notify_me_after, processor_name: processor_name, total_minutes: total_crawl_minutes)
    new_heroku_app_object = HerokuApp.using("#{processor_name}").create(status: "pending", crawl_id: new_crawl.id, verified: 'pending', user_id: user.id, processor_name: processor_name)
    ShardInfo.using(:main_shard).create(user_id: user.id, processor_name: processor_name, crawl_id: new_crawl.id, heroku_app_id: new_heroku_app_object.id)
    UserDashboard.add_pending_crawl(user.user_dashboard.id)
    # Api.delay.process_new_crawl(user_id: user.id, processor_name: processor_name)
    
    Api.delay.process_new_crawl('crawl_id' => new_crawl.id, 'user_id' => user_id, 'processor_name' => processor_name)
    
    # Crawl.decision_maker('crawl_id' => new_crawl.id, 'user_id' => user_id, 'processor_name' => processor_name)
  end
  
  def self.save_new_keyword_crawl(user_id, keyword, options = {})
    user = User.using(:main_shard).find(user_id)
    plan = user.subscription.plan
    beta = true
    name = options[:name]
    moz_da = options[:moz_da].nil? ? nil : options[:moz_da].to_i
    majestic_tf = options[:majestic_tf].nil? ? nil : options[:majestic_tf].to_i
    notify_me_after = options[:notify_me_after].nil? ? nil : options[:notify_me_after].to_i
    crawl_start_date = options[:crawl_start_date].nil? ? '' : options[:crawl_start_date]
    crawl_end_date = options[:crawl_end_date].nil? ? '' : options[:crawl_end_date]
    total_crawl_minutes = ((options[:hours].to_i*60)+options[:minutes].to_i)
    puts "the total crawl minutes are #{total_crawl_minutes}"
    
    if beta == true
      if options[:maxpages].nil?
        maxpages = 10
      else
        maxpages = options[:maxpages].to_i > 500 ? 500 : options[:maxpages].to_i
      end
    else
      maxpages = options[:maxpages].empty? ? 10 : options[:maxpages].to_i
    end
    
    processors_hash = {}
    processors_array = ['processor_three', 'processor_four', 'processor', 'processor_one', 'processor_two']
    processors_array.each do |processor_name|
      running_count = Crawl.using(processor_name).where(status: 'running').count
      processors_hash[processor_name] = running_count
    end
    processor_name = processors_hash.sort_by{|k,v|v}[0][0]
    
    new_crawl = Crawl.using("#{processor_name}").create(user_id: user_id, name: name, maxpages: maxpages, crawl_type: 'keyword_crawl', base_keyword: keyword, status: 'pending', crawl_start_date: crawl_start_date, crawl_end_date: crawl_end_date, max_pages_allowed: plan.pages_per_crawl.to_i, moz_da: moz_da, majestic_tf: majestic_tf, notify_me_after: notify_me_after, iteration: 0, processor_name: processor_name, total_minutes: total_crawl_minutes)
    new_heroku_app_object = HerokuApp.using("#{processor_name}").create(status: "pending", crawl_id: new_crawl.id, verified: 'pending', user_id: user_id, processor_name: processor_name)
    ShardInfo.using(:main_shard).create(user_id: user.id, processor_name: processor_name, crawl_id: new_crawl.id, heroku_app_id: new_heroku_app_object.id)
    UserDashboard.add_pending_crawl(user.user_dashboard.id)
    # Crawl.decision_maker(user_id)
    # Api.delay.process_new_crawl(user_id: user_id, processor_name: processor_name)
    
    Api.delay.process_new_crawl('crawl_id' => new_crawl.id, 'user_id' => user_id, 'processor_name' => processor_name)
    
    # Crawl.decision_maker('crawl_id' => new_crawl.id, 'user_id' => user_id, 'processor_name' => processor_name)
  end
  
  def self.save_new_sites(crawl_id, options={})
    processor_name = options['processor_name']
    crawl = Crawl.using("#{processor_name}").find(crawl_id)
    
    crawl.base_urls.each do |u|
      new_site = Site.using("#{processor_name}").create(base_url: u.to_s, maxpages: crawl.maxpages.to_i, crawl_id: crawl_id, processing_status: "pending")
      new_site.create_gather_links_batch(status: "pending")
    end
    
    GatherLinks.delay.start('crawl_id' => crawl.id, 'processor_name' => processor_name)
  end
  
  def self.update_all_crawl_stats(user_id)
    user = User.find(user_id)
    crawls = user.crawls.select('id')
    crawls.each do |c|
      Crawl.update_stats(c.id)
    end
  end
  
  def self.update_stats(crawl_id)
    crawl = Crawl.find(crawl_id)
    total_expired = crawl.pages.where(available: 'true').count
    Crawl.update(crawl.id, total_expired: total_expired.to_i)
  end
  
  
  def self.crawl_stats(broken, available)
    # crawl = Crawl.using(:processor).find(crawl_id)
    # broken = crawl.total_broken.to_i
    # available = crawl.total_expired.to_i
    
    LazyHighCharts::HighChart.new('graph') do |f|
      #f.title(:text => "Population vs GDP For 5 Big Countries [2009]")
      f.xAxis(:categories => ["Broken", "Available"])
      f.series(:showInLegend => false , :data => [broken, available])
      #f.series(:name => "Population in Millions", :yAxis => 1, :data => [310, 127, 1340, 81, 65])

      f.yAxis [
        {:title => {:text => ""} }
      ]

      #f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
      f.chart({:defaultSeriesType=>"bar", backgroundColor: "#F4F4F2"})
    end
  end


  def self.site_stats(site_id)
    site = Site.find(site_id)
    internal = site.pages.where(internal: true).uniq.count
    external = site.pages.where(internal: false).uniq.count
    broken = site.pages.where(status_code: '404').uniq.count
    available = site.pages.where(status_code: '0', internal: false).uniq.count

    LazyHighCharts::HighChart.new('graph') do |f|
      #f.title(:text => "Population vs GDP For 5 Big Countries [2009]")
      f.xAxis(:categories => ["Internal", "External", "Broken", "Available"])
      f.series(:showInLegend => false , :data => [internal, external, broken, available])
      #f.series(:name => "Population in Millions", :yAxis => 1, :data => [310, 127, 1340, 81, 65])

      f.yAxis [
        {:title => {:text => ""} }
      ]

      #f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
      f.chart({:defaultSeriesType=>"bar", backgroundColor: "#F4F4F2"})
    end
  end
  
  def cache_available_sites
    cache = Rails.cache.read(["crawl/#{self.id}/available/#{self.processor_name}"])
    
    if cache.nil?
      puts "setting available sites cache for the crawl #{self.id}"
      return Page.using("#{self.processor_name}").where(crawl_id: self.id, available: 'true')
    else
      puts "gettin available sites from cache for crawl #{self.id}"
      return cache
    end
  end
  
  def self.save_all_available_sites
    user_ids_array = Subscription.using(:main_shard).where(status: 'active').map(&:user_id)
    user_ids_array.each do |user_id|
      puts "the user id is #{user_id}"
      processors_array = ['processor', 'processor_one', 'processor_two', 'processor_three', 'processor_four']
      processors_array.each do |processor|
        puts "saving new available sites"
        Crawl.using("#{processor}").where(user_id: user_id.to_i).each{|c| c.save_available_sites}
      end
    end
  end
  
  def save_available_sites(options={})
    self.available_sites = Page.using("#{self.processor_name}").where(available: 'true', crawl_id: self.id).pluck(:id, :simple_url, :da, :pa, :trustflow, :citationflow, :refdomains, :backlinks)
    self.save!
    return self.available_sites
  end
  
  def available_to_csv
    attributes = %w[simple_url da pa trustflow citationflow refdomains backlinks]
    CSV.generate(headers: true) do |csv|
      csv << attributes
      self.available_sites.each do |page|
        csv << [page[1], page[2], page[3], page[4], page[5], page[6], page[7]]
      end
    end
  end
  
  def self.delete_all_crawls
    apps = HerokuPlatform.new.app_list
    apps.each do |app|
      if app['name'].include?('revivecrawler')
        begin
          puts "delete_all_crawls: deleting crawl #{app['name']}"
          HerokuPlatform.new.delete_app(app['name'])
        rescue
          puts "delete_all_crawls: failed to delete crawl #{app['name']}"
        end
      end
    end
  end
  
end
