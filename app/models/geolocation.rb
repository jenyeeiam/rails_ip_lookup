class Geolocation < ApplicationRecord
  before_validation :prepend_scheme_to_url

  validates :coordinates, presence: true
  validates :ip, uniqueness: true,
                 format: { with: Resolv::IPv4::Regex, message: "must be a valid IPv4 address" }
  validates :url, url: { allow_blank: true }
  validates :country_code, length: { maximum: 3 }
  validates :country_name, length: { maximum: 100 }
  validates :region_code, length: { maximum: 10 }
  validates :city, length: { maximum: 100 }

  def self.find_by_ip_or_url(value)
    where("ip = ? OR url = ?", value, value).first
  end

  private

  def prepend_scheme_to_url
    return if url.blank? || url =~ /\Ahttps?:\/\//

    self.url = "http://#{url}"
  end
end
