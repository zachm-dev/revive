class UserDashboard < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :user_id

  def self.update_stats(dashboard_id, options={})
    puts "updating user dashboard #{dashboard_id} with metrics #{options}"
    dash = UserDashboard.find(dashboard_id)
    dash.update(domains_crawled: dash.domains_crawled.to_i + options[:domains_crawled].to_i, 
                domains_broken: dash.domains_broken.to_i + options[:domains_broken].to_i, 
                domains_expired: dash.domains_expired.to_i + options[:domains_expired].to_i)
  end

end
