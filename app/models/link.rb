class Link < ActiveRecord::Base
  #serialize :links, Array
  belongs_to :site
  #after_create :start_processing
  
  private
    
  def start_processing
    ProcessLinks.start(self.id)
  end
  
end
