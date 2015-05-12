class DeleteDomains
  attr_reader :page_infos, :user

  def initialize(params, user)
    @page_infos = params[:page_infos]
    @user = user
  end

  def go
    page_infos.each do |page_info|
      page_info_obj = PageInfo.new(page_info)
      page = Page.using(page_info_obj.processor).find page_info_obj.id
      raise page.inspect
      crawl = Crawl.find_by page_id: page.id, user_id: user.id
      raise crawl.inspect
    end
  end

  class PageInfo
    attr_reader :id, :processor

    def initialize(info)
      info_array = info.split(',')
      @id = info_array[0]
      @processor = info_array[1]
    end
  end
end
