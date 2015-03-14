class SaveSitesFromGoogle
  
  include Sidekiq::Worker
  sidekiq_options retry: false
  
  def perform(crawl_id, options = {})
    crawl = Crawl.using(:main_shard).find(crawl_id)
    if !options['google_param'].nil?
      if crawl.crawl_start_date.nil? && crawl.crawl_end_date.nil?
        puts "the google query is https://www.google.com/search?num=10&rlz=1C5CHFA_enUS561US561&es_sm=119&q=#{crawl.base_keyword}+#{options['google_param']}&spell=1&sa=X&ei=mx7SVKn0IoboUtrdgsAL&ved=0CBwQvwUoAA&biw=1280&bih=701"
        uri = URI.parse(URI.encode("https://www.google.com/search?num=10&rlz=1C5CHFA_enUS561US561&es_sm=119&q=#{crawl.base_keyword}+#{options['google_param']}&spell=1&sa=X&ei=mx7SVKn0IoboUtrdgsAL&ved=0CBwQvwUoAA&biw=1280&bih=701"))
      else
        puts "the timed google query is https://www.google.com/search?num=10&rlz=1C5CHFA_enUS561US561&es_sm=119&q=#{crawl.base_keyword}+#{options['google_param']}&spell=1&sa=X&ei=mx7SVKn0IoboUtrdgsAL&ved=0CBwQvwUoAA&biw=1280&bih=701&source=lnt&tbs=cdr%3A1%2Ccd_min%3A#{crawl.crawl_start_date}%2Ccd_max%3A#{crawl.crawl_end_date}&tbm="
        uri = URI.parse(URI.encode("https://www.google.com/search?num=10&rlz=1C5CHFA_enUS561US561&es_sm=119&q=#{crawl.base_keyword}+#{options['google_param']}&spell=1&sa=X&ei=mx7SVKn0IoboUtrdgsAL&ved=0CBwQvwUoAA&biw=1280&bih=701&source=lnt&tbs=cdr%3A1%2Ccd_min%3A#{crawl.crawl_start_date}%2Ccd_max%3A#{crawl.crawl_end_date}&tbm="))
      end
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
    
    urls_array.each do |u|
      puts "the gather links batch of keyword crawl #{u}"
      site = Site.using(:main_shard).create(base_url: u.to_s, maxpages: crawl.maxpages.to_i, crawl_id: crawl_id, processing_status: "pending")
      GatherLinksBatch.using(:main_shard).create(site_id: site.id, status: "pending")
    end
  end
  
  def on_complete(status, options)
    puts "finished saving sites from google for the crawl #{options['crawl_id']}"
    # crawl = Crawl.using(:main_shard).find(options['crawl_id'])
    Site.save_url_domains(crawl_id: options['crawl_id'])
    # Site.save_moz_data(crawl_id: options['crawl_id'])
    # Site.save_majestic_data(crawl_id: options['crawl_id'])
    # ids = Site.in_the_top_x_percent(20, options['crawl_id'])
    # crawl.sites.each do |site|
    #   puts "the gather links batch of keyword crawl #{site.id}"
    #   site.update(processing_status: "pending")
    #   GatherLinksBatch.using(:main_shard).create(site_id: site.id, status: "pending")
    # end
    GatherLinks.delay.start('crawl_id' => options['crawl_id'])
    # Crawl.delay.decision_maker(crawl.user.id)
  end
  
  def self.start_batch(crawl_id)
    google_links_batch = Sidekiq::Batch.new
    puts "the crawl id for this google batch is #{crawl_id}"
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