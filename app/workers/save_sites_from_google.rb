class SaveSitesFromGoogle
  
  include Sidekiq::Worker
  sidekiq_options retry: false
  
  def perform(crawl_id, options = {})
    crawl = Crawl.find(crawl_id)
    if !options['google_param'].nil?
      uri = URI.parse(URI.encode("https://www.google.com/search?num=10&rlz=1C5CHFA_enUS561US561&es_sm=119&q=#{crawl.base_keyword}+#{options['google_param']}&spell=1&sa=X&ei=mx7SVKn0IoboUtrdgsAL&ved=0CBwQvwUoAA&biw=1280&bih=701"))
    end
    page = Nokogiri::HTML(open(uri))
    urls_array = []
    page.css('h3.r').map do |link|
      url = link.children[0].attributes['href'].value
      if url.include?('url?q')
        split_url = url.split("=")[1]
        if split_url.include?('&')
          remove_and_from_url = split_url.split("&")[0]
          urls_array << remove_and_from_url
        end
      end
    end
    urls_array.map do |u|
      Site.create(base_url: u.to_s, maxpages: crawl.maxpages.to_i, crawl_id: crawl_id)
    end
  end
  
  def on_complete(status, options)
    puts 'finished saving sites from google'
    crawl = Crawl.find(options['crawl_id'])
    Site.save_url_domains(crawl_id: options['crawl_id'])
    Site.save_moz_data(crawl_id: options['crawl_id'])
    # Site.save_majestic_data(crawl_id: options['crawl_id'])
    ids = Site.in_the_top_x_percent(20, options['crawl_id'])
    sites = Site.find(ids)
    sites.each do |site|
      site.update(processing_status: "pending")
      site.create_gather_links_batch(status: "pending")
    end
    GatherLinks.delay.start('crawl_id' => crawl.id)
    # Crawl.delay.decision_maker(crawl.user.id)
  end
  
  def self.start_batch(crawl_id)
    google_links_batch = Sidekiq::Batch.new
    google_links_batch.on(:complete, self, 'bid' => google_links_batch.bid, 'crawl_id' => crawl_id)
    google_links_batch.jobs do
      
      Crawl::GOOGLE_PARAMS.each do |param|
        begin
          SaveSitesFromGoogle.perform_async(crawl_id, 'google_param' => param)
        rescue
          puts 'failed to save'
        end
      end

    end
  end
  
end