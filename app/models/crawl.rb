require 'retriever'
require 'domainatrix'

class Crawl < ActiveRecord::Base
  
  belongs_to :user
  has_many :sites
  has_many :pages, through: :sites
  
  def self.decision_maker(user_id)
    user = User.find(user_id)
    pending_count = user.gather_links_batches.where(status: "pending").count
    running_count = user.gather_links_batches.where(status: "running").count
    if pending_count > 0 && running_count < 1
      memory_stats = Heroku.memory_stats
      if memory_stats.include?("red")
        Heroku.scale_dyno(user_id: user_id)
        puts "Scale dyno formation"
      else
        site_to_crawl_id = user.gather_links_batches.where(status: "pending").first.site.id
        GatherLinks.start(site_to_crawl_id)
      end
    end
  end
  
  def self.hydra(id)
    links = Link.find(id).links
    hydra = Typhoeus::Hydra.new
    
    links.map do |l|
      request = Typhoeus::Request.new(l, followlocation: true, method: :get, connecttimeout: 1, timeout: 1)
      
      request.on_complete do |response|
        if response.success?
          puts "hell yeah"
        elsif response.timed_out?
          # aw hell no
          puts "got a time out"
        elsif response.code == 0
          # Could not get an http response, something's wrong.
          puts "#{response.return_message}"
        else
          # Received a non-successful http response.
          puts "HTTP request failed: #{response.code}"
        end
      end
      
      hydra.queue(request)
    end
    
    hydra.run
    
  end
  
  def self.sites(user_id, base_urls, options = {})
    
    #name = eval("#{name}").first
    user = User.find(user_id)
    name = options[:name]
    maxpages = options[:maxpages].empty? ? 10 : options[:maxpages].to_i
    new_crawl = user.crawls.create(name: name, maxpages: maxpages)
    
    if base_urls.include?("\r\n")
      urls_array = base_urls.split(/[\r\n]+/).map(&:strip)
    else
      urls_array = base_urls.split(",")
    end
    
    urls_array.each do |u|
      new_site = new_crawl.sites.create(base_url: u.to_s, maxpages: maxpages)
      Crawl.delay.start(new_site.id)
    end
    
  end
  

  
  def self.start(site_id)
    
    #CrawlerWorker.perform_async(site_id)
    
    # options_hash = {
    #   valid_mime_types: ['text/html'],
    #   follow_redirects: false,
    #   # crawl_linked_external: true,
    #   redirect_limit: 0,
    #   thread_count: 10,
    #   processing_queue: "CrawlerWorker",
    #   queue_system: :sidekiq,
    #   use_encoding_safe_process_job: true,
    #   crawl_id: "#{site.crawl_id}-#{site.id}",
    #   direct_call_process_job: true
    # }
    #
    # crawler = Cobweb.new(options_hash)
    # crawler.start("#{site.base_url}")
    
    # crawler = CobwebCrawler.new(options_hash)
    # crawler.crawl("#{url}") do |page|
    #   #puts "Just crawled #{page[:url]} and got a status of #{page[:status_code]}."
    #   puts "the self object is #{page[:myoptions][:crawl_id]}"
    #   #puts "the page is #{page}"
    # end
    
    #links = []
    
    site = Site.find(site_id)

    opts = {
      'maxpages' => site.maxpages
    }
    Retriever::PageIterator.new("#{site.base_url}", opts) do |page|

      link_object = site.links.create(links: page.links, found_on: "#{page.url}")
      
      LinkWorker.perform_async(link_object.id)

    end
    
  end
  
  def self.stats(site_id)
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
  
end
