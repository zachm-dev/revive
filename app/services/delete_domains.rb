class DeleteDomains
  attr_reader :page_ids, :user

  def initialize(params, user)
    @page_ids = params[:page_ids]
    @user = user
  end

  def go
    page_ids.each do |page_id|
      page = Page.find page_id
      crawl = Crawl.find_by page_id: page.id, user_id: user.id
      raise crawl.inspect
    end
  end
end
