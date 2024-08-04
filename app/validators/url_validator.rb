class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    unless value =~ /\Ahttps?:\/\//
      value = "http://#{value}"
    end

    uri = URI.parse(value)
    unless uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS)
      record.errors.add(attribute, "is not a valid URL")
    end
  rescue URI::InvalidURIError
    record.errors.add(attribute, "is not a valid URL")
  end
end
