class Api
  require 'json'
 
  def self.start_crawl(options = {})
    
    app_name = Crawl.find(options[:crawl_id]).heroku_app.name
    
    if Rails.env.development?
      uri = URI.parse("http://localhost:3000/api_create")
      puts 'local start'
    else
      uri = URI.parse("http://#{app_name}.herokuapp.com/api_create")
      puts 'production start'
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
  
  def self.fetch_new_crawl(options={})
    
    if Rails.env.development?
      uri = URI.parse("http://localhost:3000/fetch_new_crawl")
      puts 'local done'
    else
      uri = URI.parse("http://sourcerevive.herokuapp.com/fetch_new_crawl")
      puts 'production done'
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