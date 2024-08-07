class GeolocationsController < ApplicationController
  protect_from_forgery with: :null_session

  before_action :sanitize_params, only: [ :show, :destroy, :create ]

  def index
    begin
      geolocations = Geolocation.order(created_at: :desc).limit(100)
      render json: geolocations
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid => e
      render json: { error: "Database connection error: #{e.message}" }, status: :service_unavailable
    rescue StandardError => e
      render json: { error: "An unexpected error occurred: #{e.message}" }, status: :internal_server_error
    end
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
      existing_geolocation = Geolocation.find_by_ip_or_url(params[:value])
      if existing_geolocation
        render json: existing_geolocation, status: :ok
      else
        geolocation_data = fetch_geolocation_from_service(decoded_value)
        if geolocation_data
          new_geolocation = Geolocation.new(
            ip: geolocation_data["ip"],
            url: is_ip?(decoded_value) ? nil : decoded_value,
            coordinates: "POINT(#{geolocation_data["longitude"]} #{geolocation_data["latitude"]})",
          )
          if new_geolocation.save
            render json: new_geolocation, status: :created
          else
            render json: { errors: new_geolocation.errors.full_messages }, status: :unprocessable_entity
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
    ip_param = params[:ip]
    url_param = params[:url]

    unless (ip_param.present? && Geolocation.valid_ip?(ip_param)) || (url_param.present? && Geolocation.valid_url_format?(url_param))
      render json: { error: "A valid 'ip' or 'url' is required" }, status: :unprocessable_entity
      return
    end

    begin
      ip_or_url = ip_param || url_param
      existing_geolocation = Geolocation.find_by_ip_or_url(ip_or_url)
      if existing_geolocation
        render json: existing_geolocation, status: :ok
      else
        # Fetch the data from the service
        geolocation_data = fetch_geolocation_from_service(ip_or_url)
        if geolocation_data
          geolocation = Geolocation.new(
            ip: geolocation_data["ip"],
            url: url_param,
            coordinates: "POINT(#{geolocation_data["longitude"]} #{geolocation_data["latitude"]})",
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
      geolocation = Geolocation.find_by_ip_or_url(decoded_value)
      if geolocation
        geolocation.destroy
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
      params.permit(:ip, :url)
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

  def sanitize_params
    params.each do |key, value|
      params[key] = CGI.escapeHTML(value.to_s)
    end
  end
end
