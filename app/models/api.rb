class Api
  require 'json'
 
  def self.start_crawl(options = {})
    processor_name = options['processor_name']
    puts "the processor_name is #{options['processor_name']}"
    crawl = Crawl.using("#{processor_name}").find(options[:crawl_id])
    
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
                        :database => 'd43keikloc7ejh',
                        :username => 'uda0tbtpqg53lu',
                        :password => 'pfulh5el80spt6ehv206vs9qs1u',
                        :host => 'ec2-54-163-235-96.compute-1.amazonaws.com',
                        :port => 5482,
                        :pool => 1
                      },
                      :processor => {
                        :adapter => 'postgresql',
                        :database => 'd570jqv21u9in0',
                        :username => 'u5fkjshgbhhncg',
                        :password => 'p843pa73aoj8sm9sb4pj4ol72vo',
                        :host => 'ec2-54-163-234-153.compute-1.amazonaws.com',
                        :port => 5432,
                        :pool => 1
                      },
                      :processor_one => {
                        :adapter => 'postgresql',
                        :database => 'dbdfeisb2cpu9o',
                        :username => 'u42cj46ifes9mp',
                        :password => 'p7sgm4r42gq8niengm8ignn2pt7',
                        :host => 'ec2-54-163-236-202.compute-1.amazonaws.com',
                        :port => 5542,
                        :pool => 1
                      },
                      :processor_two => {
                        :adapter => 'postgresql',
                        :database => 'd9po7h5a2tkblk',
                        :username => 'u4p8o1fm5l007q',
                        :password => 'p48p6ff9atah28dm360flr4g3sq',
                        :host => 'ec2-54-163-237-255.compute-1.amazonaws.com',
                        :port => 5502,
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
      Crawl.using("#{processor_name}").update(crawl.id, status: 'retry')
      heroku = HerokuPlatform.new
      number_of_apps_running = heroku.app_list.count
      heroku.delete_app(crawl.heroku_app.name)
      ForkNewApp.delay.retry(app.id, number_of_apps_running, 'processor_name' => processor_name)
      
    end
    
  end
  
  def self.migrate_db(options = {})
    processor_name = options['processor_name']
    app_name = Crawl.using("#{processor_name}").find(options[:crawl_id]).heroku_app.name
    
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