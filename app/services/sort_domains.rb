class SortDomains
  attr_accessor :domains
  attr_reader :sort_key, :da_range, :tf_range, :da_range_str, :tf_range_str

  def initialize(params)
    @domains = Crawl.get_available_domains('user_id' => params[:user_id])
    @sort_key = params[:sort].nil? ? 2 : params[:sort].to_i
    @da_range_str = params[:da_range]
    @tf_range_str = params[:tf_range]
    @da_range = Range.new(da_range_str) unless da_range_str.blank?
    @tf_range = Range.new(tf_range_str) unless tf_range_str.blank?
  end

  def go
    filter_by_da_range if da_range
    self.domains = domains.sort_by{|domain_array| domain_array[sort_key].to_i }.reverse
    [domains, da_range_str, tf_range_str]
  end

  def filter_by_da_range
    self.domains = domains.select{|domain_array| domain_array[2].to_i >= da_range.min } unless da_range.min == 0
    self.domains = domains.select{|domain_array| domain_array[2].to_i <= da_range.max } unless da_range.max == 100
  end

  class Range
    attr_reader :min, :max
    def initialize(range_str)
      range_array = range_str.split(';')
      @min = range_array[0].to_i
      @max = range_array[1].to_i
    end
  end
end
