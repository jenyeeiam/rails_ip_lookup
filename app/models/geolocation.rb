require "uri"
require "public_suffix"
require "validate_url"

class Geolocation < ApplicationRecord
  before_validation :normalize_url

  validates :coordinates, presence: true
  validates :ip, uniqueness: true,
                 format: { with: Resolv::IPv4::Regex, message: "must be a valid IPv4 address" }

  validates :url, uniqueness: { allow_blank: true } # Ensure URLs are unique
  validate :custom_url_format

  def self.find_by_ip_or_url(value)
    normalized_value = normalize_url_for_query(value)
    where("ip = ? OR url = ?", value, normalized_value).first
  end

  def self.valid_ip?(ip)
    !!IPAddr.new(ip) rescue false
  end

  def self.valid_url_format?(url)
    return false if url.blank?
    return false if valid_ip?(url) # Ensure it's not an IP address

    # Regex for validating URLs and domain names
    url =~ %r{\A(?:https?:\/\/)?(?:www\.)?(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,6}(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)\z}
  end

  private

    def self.normalize_url_for_query(url)
      normalize_url(url)
    end

  def normalize_url
    self.url = self.class.normalize_url(url) if url.present?
  end

  def self.normalize_url(url)
    return nil if url.blank?

    # Add a scheme if not present
    url = "http://#{url}" unless url =~ /\A(?:https?:)?\/\//i

    uri = URI.parse(url)
    domain = uri.host || uri.path

    # Use PublicSuffix to get the domain without subdomains
    domain = PublicSuffix.domain(domain) || domain

    domain.downcase
  rescue URI::InvalidURIError, PublicSuffix::DomainInvalid
    url # Return original if parsing fails
  end

  def custom_url_format
    return if url.blank? # Allow blank URLs

    unless self.class.valid_url_format?(url)
      errors.add(:url, "must be a valid URL or domain name")
    end
  end
end
