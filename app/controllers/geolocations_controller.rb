class GeolocationsController < ApplicationController
  def index
    @geolocations = Geolocation.order(created_at: :desc).limit(100)
    render json: @geolocations
  end

  def show
    unless params[:value].present?
      render json: { error: "Parameter IP or URL is required" }, status: :unprocessable_entity
      return
    end

    decoded_value = CGI.unescape(params[:value])
    unless Geolocation.valid_ip?(decoded_value) || Geolocation.valid_url_format?(decoded_value)
      render json: { error: "Invalid IP address or URL format" }, status: :unprocessable_entity
      return
    end

    begin
      @geolocation = Geolocation.find_by_ip_or_url(params[:value])
      if @geolocation
        render json: @geolocation
      else
        geolocation_data = fetch_geolocation_from_service(decoded_value)
        if geolocation_data
          geolocation = Geolocation.new(
            ip: geolocation_data["ip"],
            url: is_ip?(decoded_value) ? nil : decoded_value,
            coordinates: "POINT(#{geolocation_data["longitude"]} #{geolocation_data["latitude"]})",
            country_code: geolocation_data["country_code"],
            country_name: geolocation_data["country_name"],
            region_code: geolocation_data["region_code"],
            city: geolocation_data["city"],
          )
          if geolocation.save
            render json: geolocation, status: :created
          else
            render json: { errors: geolocation.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { error: "Unable to fetch geolocation data" }, status: :unprocessable_entity
        end
      end
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
      render json: { error: "Database connection error: #{e.message}" }, status: :service_unavailable
    rescue StandardError => e
      render json: { error: "An unexpected error occurred: #{e.message}" }, status: :internal_server_error
    end
  end

  def create
    unless geolocation_params[:ip].present? && Geolocation.valid_ip?(geolocation_params[:ip])
      render json: { error: "A valid 'ip' is required" }, status: :unprocessable_entity
      return
    end

    begin
      @geolocation = Geolocation.new(geolocation_params.except(:latitude, :longitude))
      @geolocation.coordinates = "POINT(#{geolocation_params[:longitude]} #{geolocation_params[:latitude]})"

      if @geolocation.save
        render json: @geolocation, status: :created
      else
        render json: @geolocation.errors, status: :unprocessable_entity
      end
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
      render json: { error: "Database connection error: #{e.message}" }, status: :service_unavailable
    rescue StandardError => e
      render json: { error: "An unexpected error occurred: #{e.message}" }, status: :internal_server_error
    end
  end

  def destroy
    unless params[:value].present?
      render json: { error: "Parameter IP or URL is required" }, status: :unprocessable_entity
      return
    end

    decoded_value = CGI.unescape(params[:value])
    unless Geolocation.valid_ip?(decoded_value) || Geolocation.valid_url_format?(decoded_value)
      render json: { error: "Invalid IP address or URL format" }, status: :unprocessable_entity
      return
    end

    begin
      @geolocation = Geolocation.find_by_ip_or_url(decoded_value)
      if @geolocation
        @geolocation.destroy
        render json: { message: "Geolocation deleted" }, status: :ok
      else
        render json: { error: "Geolocation not found" }, status: :not_found
      end
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
      render json: { error: "Database connection error: #{e.message}" }, status: :service_unavailable
    rescue StandardError => e
      render json: { error: "An unexpected error occurred: #{e.message}" }, status: :internal_server_error
    end
  end

  private

    def geolocation_params
      params.require(:geolocation).permit(:ip, :url, :city, :country_code, :region_code, :latitude, :longitude)
    end

  def fetch_geolocation_from_service(ip_or_url)
    provider = :ipstack  # Change this to change service provider
    service = GeolocationServiceFactory.get_service(provider)
    service.fetch_geolocation(ip_or_url)
  rescue StandardError => e
    Rails.logger.error "Failed to fetch geolocation from service: #{e.message}"
    nil
  end

  def is_ip?(ip_or_url)
    !!(ip_or_url =~ Resolv::IPv4::Regex)
  end
end
