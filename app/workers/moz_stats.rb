require 'domainatrix'
class MozStats
  include Sidekiq::Worker
  
  def perform(page_id)
    puts 'moz perform on perform'
    page = Page.find(page_id)
    client = Linkscape::Client.new(:accessID => "ENV['linkscape_accessid']", :secret => "ENV['linkscape_secret']")
    response = client.urlMetrics([page.simple_url], :cols => :all)
    
    response.data.map do |r|
      begin
        puts "moz block perform regular"
        url = Domainatrix.parse("#{r[:uu]}")
        parsed_url = url.domain + "." + url.public_suffix
        Page.update(page.id, da: r[:pda], pa: r[:upa])
      rescue
        puts "moz block perform zero"
        Page.update(page.id, da: '0', pa: '0')
      end
    end
    
  end
  
end