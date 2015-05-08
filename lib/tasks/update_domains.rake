namespace :db do
  task :add_created_at_to_domains => :environment do
    #! need to add created_at to available sites, in Crawl.save_available_sites
    processor_names_array = ["processor", "processor_one", "processor_two", "processor_three", "processor_four"]
    #User.all.each do |user|
      user = User.find_by email: 'alex@test.com'
      crawls_array = []
      #processor_names_array.each do |processor|
        processor = 'processor'
        Crawl.using("#{processor}").where(user_id: user.id, status: 'finished').each do |crawl|
          crawls_array << {'crawl_id' => crawl.id, 'expired_count' => crawl.total_expired, 'expired_domains' => crawl.available_sites}
          puts crawls_array.count
        end
        Rails.cache.write(["user/#{user.id}/available_domains"], crawls_array)
      #end

    #end
  end
end
