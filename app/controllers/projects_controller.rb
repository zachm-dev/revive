class ProjectsController < ApplicationController
  def index
  end

  def new
    @project = Crawl.new
  end
  
  def create
    raise
  end
  
end
