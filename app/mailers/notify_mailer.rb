class NotifyMailer < ApplicationMailer
  default from: "notification@sourcerevive.net"
  
  def notify(site_id)
    @site = Site.find(site_id)
    @user = @site.crawl.user

    mail to: @user.email, subject: 'Notification Alert'
  end
end
