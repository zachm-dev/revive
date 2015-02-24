class UserDashboard < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :user_id

  def self.update_crawl_stats(dashboard_id, options={})
    puts "updating user dashboard #{dashboard_id} with metrics #{options}"
    dash = UserDashboard.find(dashboard_id)
    dash.update(domains_crawled: dash.domains_crawled.to_i + options[:domains_crawled].to_i, 
                domains_broken: dash.domains_broken.to_i + options[:domains_broken].to_i, 
                domains_expired: dash.domains_expired.to_i + options[:domains_expired].to_i)
  end
  
  def self.add_pending_crawl(dashboard_id, options={})
    puts "adding a new pending crawl"
    dash = UserDashboard.find(dashboard_id)
    dash.update(pending_crawlers: dash.pending_crawlers.to_i + 1)
  end
  
  def self.add_running_crawl(dashboard_id, options={})
    puts "adding a new running crawl and removing 1 pending crawl"
    dash = UserDashboard.find(dashboard_id)
    dash.update(pending_crawlers: (dash.pending_crawlers.to_i - 1), running_crawlers: (dash.running_crawlers.to_i + 1))
  end
  
  def self.add_finished_crawl(dashboard_id, options={})
    puts "adding a new done crawl and removing 1 running crawl"
    dash = UserDashboard.find(dashboard_id)
    dash.update(running_crawlers: (dash.running_crawlers.to_i - 1), done_crawlers: (dash.done_crawlers.to_i + 1))
  end

end
