class CreateGeolocations < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'postgis'

    create_table :geolocations do |t|
      t.st_point :coordinates, geographic: true
      t.string :ip
      t.string :url
      t.string :country_code
      t.string :country_name
      t.string :region_code
      t.string :city

      t.timestamps
    end
  end
end
