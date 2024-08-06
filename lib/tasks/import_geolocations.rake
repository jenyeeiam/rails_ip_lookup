require_relative "generate_test_data"

namespace :geolocations do
  desc "Generate and import test geolocation data"
  task import: :environment do
    generate_test_data(50)

    CSV.foreach("tmp/test_geolocations.csv", headers: true) do |row|
      geolocation = Geolocation.new(
        coordinates: row["coordinates"],
        ip: row["ip"],
        url: row["url"],
        created_at: row["created_at"],
        updated_at: row["updated_at"]
      )
      if geolocation.save
        puts "save successful"
      else
        puts "Error saving row #{row["url"]}:"
        puts geolocation.errors.full_messages.join(", ")
      end
    end

    puts "Imported #{Geolocation.count} geolocations"
  end
end
