module GeolocationService
  def fetch_geolocation(ip_or_url)
    raise NotImplementedError, "This method must be implemented by the subclass"
  end
end
