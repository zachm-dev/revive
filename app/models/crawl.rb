require 'retriever'
require 'domainatrix'

class Crawl < ActiveRecord::Base
  
  has_many :sites
  has_many :pages, through: :sites
  
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
  
  def self.test
    links = []
    opts = {
      'maxpages' => 10
    }
    t = Retriever::PageIterator.new('http://www.briancalkins.com/fitnesslinks.htm', opts) do |page|
      puts page.links
      links << page.links

    end
    links
  end
  
  def self.sites(base_urls, options = {})
    
    #name = eval("#{name}").first
    name = options[:name]
    maxpages = options[:maxpages].empty? ? 10 : options[:maxpages].to_i
    new_crawl = Crawl.create(name: name, maxpages: maxpages)
    
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
    #domain = Domainatrix.parse(site.base_url).domain

    opts = {
      'maxpages' => site.maxpages
    }
    Retriever::PageIterator.new("#{site.base_url}", opts) do |page|
      
      
      
      link_object = site.links.create(links: page.links, found_on: "#{page.url}")
      
      # #links << page.links
      # page.links.each do |l|
      #   internal = l.include?("#{domain}") ? true : false
      #   if internal == false
      #     res = Typhoeus.get("#{l}").response_code
      #   else
      #     res = ""
      #   end
      #   site.pages.create(url: l.to_s, internal: internal, status_code: res, found_on: "#{page.url}", site_id: site_id)
      # end
      
      LinkWorker.perform_async(link_object.id)

    end
    # #links
    
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
