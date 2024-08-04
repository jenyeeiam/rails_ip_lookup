class GeolocationsController < ApplicationController
  def show
    decoded_value = CGI.unescape(params[:value])
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
  end

  def create
    @geolocation = Geolocation.new(geolocation_params.except(:latitude, :longitude))
    @geolocation.coordinates = "POINT(#{geolocation_params[:longitude]} #{geolocation_params[:latitude]})"

    if @geolocation.save
      render json: @geolocation, status: :created
    else
      render json: @geolocation.errors, status: :unprocessable_entity
    end
  end

  def destroy
    decoded_value = CGI.unescape(params[:value])
    @geolocation = Geolocation.find_by_ip_or_url(decoded_value)
    if @geolocation
      @geolocation.destroy
      render json: { message: "Geolocation deleted" }, status: :ok
    else
      render json: { error: "Geolocation not found" }, status: :not_found
    end
  end

  private

  def geolocation_params
    params.require(:geolocation).permit(:ip, :url, :city, :country_code, :region_code, :latitude, :longitude)
  end

  def fetch_geolocation_from_service(ip_or_url)
    provider = :ipstack # Change this to switch providers
    service = GeolocationServiceFactory.get_service(provider)
    service.fetch_geolocation(ip_or_url)
  end

  def is_ip?(ip_or_url)
    ip_or_url =~ /\A\d{1,3}(\.\d{1,3}){3}\z/
  end
end
