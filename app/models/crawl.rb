class Crawl < ActiveRecord::Base
  has_many :sites
  
  def self.sites(base_urls, *name)
    
    name = eval("#{name}").first
    new_crawl = Crawl.create(name: name)
    
    if base_urls.include?("\r\n")
      urls_array = base_urls.split(/[\r\n]+/).map(&:strip)
    else
      urls_array = base_urls.split(",")
    end
    
    urls_array.each do |u|
      new_site = new_crawl.sites.create(base_url: u.to_s)
      Crawl.start(new_site.id)
    end
    
  end
  
  def self.start(site_id)
    
    site = Site.find(site_id)
    
    options_hash = {
      valid_mime_types: ['text/html'],
      follow_redirects: true, 
      crawl_linked_external: true, 
      redirect_limit: 6, 
      thread_count: 20,
      processing_queue: "CrawlerWorker",
      queue_system: :sidekiq,
      use_encoding_safe_process_job: true,
      crawl_id: "#{site.crawl_id}-#{site.id}",
      direct_call_process_job: true
    }
    
    crawler = Cobweb.new(options_hash)
    crawler.start("#{site.base_url}")
    
    # crawler = CobwebCrawler.new(options_hash)
    # crawler.crawl("#{url}") do |page|
    #   #puts "Just crawled #{page[:url]} and got a status of #{page[:status_code]}."
    #   puts "the self object is #{page[:myoptions][:crawl_id]}"
    #   #puts "the page is #{page}"
    # end
    
  end
  
  def self.stats
    LazyHighCharts::HighChart.new('graph') do |f|
      #f.title(:text => "Population vs GDP For 5 Big Countries [2009]")
      f.xAxis(:categories => ["Urls", "Domains", "Pages"])
      f.series(:name => "GDP in Billions", :showInLegend => false , :data => [14119, 5068, 4985])
      #f.series(:name => "Population in Millions", :yAxis => 1, :data => [310, 127, 1340, 81, 65])

      f.yAxis [
        {:title => {:text => ""} }
      ]

      #f.legend(:align => 'right', :verticalAlign => 'top', :y => 75, :x => -50, :layout => 'vertical',)
      f.chart({:defaultSeriesType=>"bar", backgroundColor: "#F4F4F2"})
    end
  end
  
end
