class GeolocationServiceFactory
  def self.get_service(provider)
    case provider
    when :ipstack
      IpStackService.new
    else
      raise "Unsupported geolocation service provider"
    end
  end
end
