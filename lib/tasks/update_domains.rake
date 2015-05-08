namespace :db do
  task :update_available_sites => :environment do
    #processors_array = ['processor', 'processor_one', 'processor_two', 'processor_three', 'processor_four']
    processors_array = ['processor']
    processors_array.each do |processor|
      @count = 0
      Crawl.using("#{processor}").where(status: 'finished').each{|c|
        c.save_available_sites
        puts "crawl count: #{@count}"
        @count += 1
      }
    end
  end

  task :reload_crawls_cache => :environment do
    #! need to add created_at to available sites, in Crawl.save_available_sites
    #processor_array = ["processor", "processor_one", "processor_two", "processor_three", "processor_four"]
    processors_array = ['processor']
    #User.all.each do |user|
      user = User.find_by email: 'alex@test.com'
      crawls_array = []
      processors_array.each do |processor|
        Crawl.using("#{processor}").where(user_id: user.id, status: 'finished').each do |crawl|
          crawls_array << {'crawl_id' => crawl.id, 'expired_count' => crawl.total_expired, 'expired_domains' => crawl.available_sites}
          puts crawls_array.count
        end
        Rails.cache.write(["user/#{user.id}/available_domains"], crawls_array)
      end

    #end
  end
end
