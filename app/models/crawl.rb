require 'retriever'
require 'domainatrix'

class Crawl < ActiveRecord::Base
  
  belongs_to :user
  has_many :sites
  has_many :pages, through: :sites
  has_many :links, through: :sites
  has_many :gather_links_batches, through: :sites
  has_many :process_links_batches, through: :sites
  has_one :heroku_app
  
  def self.decision_maker(user_id)
    
    user = User.find(user_id)
    
    number_of_pending_crawls = user.heroku_apps.where(status: "pending").count
    number_of_running_crawls = user.heroku_apps.where(status: "running").count
    
    if number_of_pending_crawls > 0 #&& number_of_running_crawls < 1
      number_of_apps_running = Heroku.app_list.count
      if number_of_apps_running < 95
        ForkNewApp.start(user_id)
      end
    end
    
  end
  
  def self.save_new_crawl(user_id, base_urls, options = {})
    
    user = User.find(user_id)
    beta = true
    name = options[:name]
    
    if beta == true
      if options[:maxpages].nil?
        maxpages = 10
      else
        maxpages = options[:maxpages].to_i > 500 ? 500 : options[:maxpages].to_i
      end
    else
      maxpages = options[:maxpages].empty? ? 10 : options[:maxpages].to_i
    end
    
    new_crawl = Crawl.create(user_id: user_id, name: name, maxpages: maxpages)
    new_heroku_app_object = HerokuApp.create(status: "pending", crawl_id: new_crawl.id, verified: 'pending')
    save_new_sites = Crawl.save_new_sites(base_urls, new_crawl.id)
    Crawl.decision_maker(user_id)
  end
  
  def self.save_new_sites(base_urls, crawl_id)
    
    crawl = Crawl.find(crawl_id)

    if base_urls.include?("\r\n")
      urls_array = base_urls.split(/[\r\n]+/).map(&:strip)
    else
      urls_array = base_urls.split(",")
    end
    
    urls_array.each do |u|
      new_site = Site.create(base_url: u.to_s, maxpages: crawl.maxpages.to_i, crawl_id: crawl_id)
      new_site.create_gather_links_batch(status: "pending")
      #Crawl.delay.decision_maker(user_id)
    end
    crawl.update(total_sites: crawl.sites.count)
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
  
  
  def self.crawl_stats(crawl_id)
    crawl = Crawl.find(crawl_id)
    internal = crawl.pages.where(internal: true).uniq.count
    external = crawl.pages.where(internal: false).uniq.count
    broken = crawl.pages.where(status_code: '404').uniq.count
    available = crawl.pages.where(status_code: '0', internal: false).uniq.count
    
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
  
end
