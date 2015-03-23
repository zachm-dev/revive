class Api
  require 'json'
 
  def self.start_crawl(options = {})
    
    crawl = Crawl.using(:processor).find(options[:crawl_id])
    db = crawl.db_url
    uri = URI.parse(db)
    Octopus.setup do |config|
      config.shards = {:test_connection => {
                        :adapter => 'postgresql',
                        :database => db.split('/').last,
                        :username => uri.user,
                        :password => uri.password,
                        :host => uri.host,
                        :port => uri.port
                      },
                      :main_shard => {
                        :adapter => 'postgresql',
                        :database => 'daji1hvabgdc0c',
                        :username => 'ue9r4mdvjgsktq',
                        :password => 'p9rem1q40biu605siarnkvp2i83',
                        :host => 'ec2-184-73-202-38.compute-1.amazonaws.com',
                        :port => 5532,
                        :pool => 1
                      },
                      :processor => {
                        :adapter => 'postgresql',
                        :database => 'd20vpq28o48gs4',
                        :username => 'uaatonnj4p4fbc',
                        :password => 'p6tpu937gn4fk5ehvfnlru5aiq3',
                        :host => 'ec2-54-163-226-12.compute-1.amazonaws.com',
                        :port => 5482,
                        :pool => 1
                      }
                    }
    end

                    
    begin
      Page.using(:test_connection).last
      puts 'db migration was sucessful '
      app_name = crawl.heroku_app.name
    
      if Rails.env.development?
        uri = URI.parse("http://localhost:3000/api_create")
        puts "production start #{app_name}"
      else
        uri = URI.parse("http://#{app_name}.herokuapp.com/api_create")
        puts "production start #{app_name}"
      end
        
      post_params = {
        :options => options
      }
 
      # Convert the parameters into JSON and set the content type as application/json
      req = Net::HTTP::Post.new(uri.path)
      req.body = JSON.generate(post_params)
  
      http = Net::HTTP.new(uri.host, uri.port)
      response = http.start {|htt| htt.request(req)}
      
    rescue
      # puts 'retrying db migration'
      # Api.delay.migrate_db(crawl_id: crawl.id)
      # Api.delay_for(1.minute).start_crawl(crawl_id: crawl.id)
      #
      app = crawl.heroku_app
      puts 'new app did not start properly'
      app.update(status: 'retry')
      Crawl.update(crawl.id, status: 'retry')
      heroku = HerokuPlatform.new
      number_of_apps_running = heroku.app_list.count
      heroku.delete_app(crawl.heroku_app.name)
      ForkNewApp.delay.retry(app.id, number_of_apps_running)
      
    end
    
  end
  
  def self.migrate_db(options = {})
    
    app_name = Crawl.find(options[:crawl_id]).heroku_app.name
    
    if Rails.env.development?
      uri = URI.parse("http://localhost:3000/migrate_db")
      puts "production start #{app_name}"
    else
      uri = URI.parse("http://#{app_name}.herokuapp.com/migrate_db")
      puts "production start #{app_name}"
    end
        
    post_params = {
      :options => options
    }
    
    # post_params = {
    #   :user_id => user_id,
    #   :urls => urls,
    #   :options => options
    # }
 
    # Convert the parameters into JSON and set the content type as application/json
    req = Net::HTTP::Post.new(uri.path)
    req.body = JSON.generate(post_params)
    #req["Content-Type"] = "application/json"
  
    http = Net::HTTP.new(uri.host, uri.port)
    response = http.start {|htt| htt.request(req)}
  end
  
  def self.process_new_crawl(options={})
    if Rails.env.development?
      uri = URI.parse("http://localhost:3000/process_new_crawl")
      puts 'processing new crawl local'
    else
      uri = URI.parse("http://reviveprocessor.herokuapp.com/process_new_crawl")
      puts 'processing new crawl production'
    end
    
    post_params = {
      :options => options
    }
    
    # Convert the parameters into JSON and set the content type as application/json
    req = Net::HTTP::Post.new(uri.path)
    req.body = JSON.generate(post_params)
    #req["Content-Type"] = "application/json"
  
    http = Net::HTTP.new(uri.host, uri.port)
    response = http.start {|htt| htt.request(req)}
  end
  
end