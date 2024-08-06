FactoryBot.define do
  factory :geolocation do
    coordinates { "POINT(-122.4194 37.7749)" }
    sequence(:ip) { |n| "192.168.1.#{n}" }
    url { "http://example#{rand(1000)}.com" }
  end
end
