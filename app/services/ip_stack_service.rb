class IpStackService
  include GeolocationService

  def fetch_geolocation(ip_or_url)
    api_key = Rails.application.credentials.dig(:ipstack, :api_key)
    # Remove http:// or https:// if present
    cleaned_ip_or_url = ip_or_url
    begin
      uri = URI.parse(ip_or_url)
      cleaned_ip_or_url = uri.host if uri.host
    rescue URI::InvalidURIError
      # If it's not a valid URI, assume it's an IP address
      cleaned_ip_or_url = ip_or_url
    end
    response = HTTParty.get("http://api.ipstack.com/#{cleaned_ip_or_url}?access_key=#{api_key}")
    parsed_response = JSON.parse(response.body)

    if parsed_response["success"] == false
      error_info = parsed_response["error"]
      Rails.logger.error "IPStack API error: #{error_info['type']} - #{error_info['info']}"
      return nil
    end

    # Process successful response here
    parsed_response

  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "Timeout error fetching geolocation from ipstack: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.error "Error fetching geolocation from ipstack: #{e.message}"
    nil
  end
end
