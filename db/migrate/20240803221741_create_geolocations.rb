class CreateGeolocations < ActiveRecord::Migration[7.1]
  def change
    enable_extension 'postgis'

    create_table :geolocations do |t|
      t.st_point :coordinates, geographic: true
      t.string :ip
      t.string :url

      t.timestamps
    end

    # Adding unique index on ip and url, allowing url to be NULL
    add_index :geolocations, [ :ip, :url ], unique: true, where: 'url IS NOT NULL'
    add_index :geolocations, :ip, unique: true, where: 'url IS NULL'
  end
end
