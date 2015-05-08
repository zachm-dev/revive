namespace :db do
  task :update_available_sites => :environment do
    processors_array = ['processor', 'processor_one', 'processor_two', 'processor_three', 'processor_four']
    @count = 0
    user = User.find_by email: 'alex@test.com'
    processors_array.each do |processor|
      Crawl.using("#{processor}").where(user_id: user.id, status: 'finished').each{|c|
        puts "Crawl id: #{c.id} - #{c.created_at} - #{processor}"
        c.save_available_sites
        puts "crawl count: #{@count}"
        @count += 1
      }
    end
  end

  task :reload_crawls_cache => :environment do
    processors_array = ["processor", "processor_one", "processor_two", "processor_three", "processor_four"]
    #User.all.each do |user|
      user = User.find_by email: 'alex@test.com'
      crawls_array = []
      count = 0
      processors_array.each do |processor|
        Crawl.using("#{processor}").where(user_id: user.id, status: 'finished').each do |crawl|
          crawls_array << {'crawl_id' => crawl.id, 'expired_count' => crawl.total_expired, 'expired_domains' => crawl.available_sites}
          puts crawls_array.count
          count += 1
          puts "count: #{count}"
        end
        Rails.cache.write(["user/#{user.id}/available_domains"], crawls_array)
      end
    #end
  end
end
