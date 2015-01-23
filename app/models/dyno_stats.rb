class DynoStats
  
  LIBRATO_EMAIL = "ENV['librato_email']"
  LIBRATO_KEY = "ENV['librato_key']"
  
  def initialize
    librato = Librato::Metrics.authenticate(LIBRATO_EMAIL, LIBRATO_KEY)
  end
  
  def metrics(options = {})
    metrics = Librato::Metrics.get_measurements "#{options[:metric]}".to_sym, :count => 1, source: "#{options[:source]}", resolution: 60
    return metrics["#{options[:source]}"][0]
  end
  
end