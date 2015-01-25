class Api
  require 'json'
 
  def self.post
    uri = URI.parse("http://sourcerevive.net/crawls")
 
    post_params = { 
      :title => "2BR Apartment For Rent in NYC",
      :description => "Great midtown west location. I love this place.",
      :price => "1500"
    }
 
    # Convert the parameters into JSON and set the content type as application/json
    req = Net::HTTP::Post.new(uri.path)
    req.body = JSON.generate(post_params)
    req["Content-Type"] = "application/json"
  
    http = Net::HTTP.new(uri.host, uri.port)
    response = http.start {|htt| htt.request(req)}
  end
end