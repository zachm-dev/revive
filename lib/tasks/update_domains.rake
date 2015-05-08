namespace :db do
  task :update_available_sites => :environment do
    processors_array = ['processor', 'processor_one', 'processor_two', 'processor_three', 'processor_four']
    user_count = 0
    User.all.each do |user|
      crawl_count = 0
      processors_array.each do |processor|
        Crawl.using("#{processor}").where(user_id: user.id, status: 'finished').each{|c|
          puts "Crawl id: #{c.id} - #{c.created_at} - #{processor}"
          c.save_available_sites
          puts "crawl count: #{crawl_count}"
          crawl_count += 1
        }
      end
      puts "user count: #{user_count}"
      user_count += 1
    end
  end

  task :reload_crawls_cache => :environment do
    processors_array = ["processor", "processor_one", "processor_two", "processor_three", "processor_four"]
    user_count = 0
    User.all.each do |user|
      crawls_array = []
      crawl_count = 0
      processors_array.each do |processor|
        Crawl.using("#{processor}").where(user_id: user.id, status: 'finished').each do |crawl|
          crawls_array << {'crawl_id' => crawl.id, 'expired_count' => crawl.total_expired, 'expired_domains' => crawl.available_sites}
          puts crawls_array.count
          crawl_count += 1
          puts " crawl count: #{crawl_count}"
        end
        Rails.cache.write(["user/#{user.id}/available_domains"], crawls_array)
      end
      puts "user count: #{user_count}"
      user_count += 1
    end
  end
end
