class UserDashboard < ActiveRecord::Base
  belongs_to :user
  validates_uniqueness_of :user_id

  # def increment(options={})
  #   self.update(domains_crawled: domains_crawled.to_i + options[:domains_crawled].to_i, domains_expired: domains_expired.to_i + options[:domains_expired].to_i,
  #       domains_broken: domains_broken.to_i + options[:domains_crawled].to_i)
  # end

  def self.increment(options={})
    self.update(domains_crawled: dashboard.domains_crawled.to_i + options[:domains_crawled].to_i,
                         domains_expired: dashboard.domains_expired.to_i + options[:domains_expired].to_i,
                         domains_broken: dashboard.domains_broken.to_i + options[:domains_crawled].to_i)
  end

end
