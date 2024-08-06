require "csv"
require "faker"

def generate_test_data(num_records = 100)
  CSV.open("tmp/test_geolocations.csv", "w") do |csv|
    csv << [ "coordinates", "ip", "url", "created_at", "updated_at" ]

    num_records.times do
      lat = Faker::Address.latitude
      lon = Faker::Address.longitude
      csv << [
        "POINT(#{lon} #{lat})",
        Faker::Internet.ip_v4_address,
        Faker::Internet.url,
        Faker::Time.between(from: 2.years.ago, to: Time.now),
        Faker::Time.between(from: 2.years.ago, to: Time.now)
      ]
    end
  end
end
