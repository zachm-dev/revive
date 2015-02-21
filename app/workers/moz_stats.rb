require 'domainatrix'
class MozStats
  include Sidekiq::Worker
  
  def perform(page_id)
    puts 'moz perform on perform'
    page = Page.find(page_id)
    client = Linkscape::Client.new(:accessID => "member-8967f7dff3", :secret => "8b98d4acd435d50482ebeded953e2331")
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