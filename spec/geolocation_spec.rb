require "rails_helper"

RSpec.describe Geolocation, type: :model do
  subject { build(:geolocation) }

  describe "validations" do
    it { should validate_presence_of(:coordinates) }
    it { should validate_uniqueness_of(:ip).case_insensitive }
    it { should allow_value("192.168.1.1").for(:ip) }
    it { should_not allow_value("999.999.999.999").for(:ip) }
    it { should allow_value(nil).for(:url) }
    it { should_not allow_value("invalid_ip").for(:ip) }
    it { should allow_value("http://example.com").for(:url) }
    it { should allow_value("https://example.com").for(:url) }
    it { should allow_value("example.com").for(:url) }
    it { should_not allow_value("invalid_url").for(:url) }
    it { should validate_length_of(:country_code).is_at_most(3) }
    it { should validate_length_of(:country_name).is_at_most(100) }
    it { should validate_length_of(:region_code).is_at_most(10) }
    it { should validate_length_of(:city).is_at_most(100) }
  end

  describe "callbacks" do
    it "normalizes the URL before validation" do
      geo = Geolocation.new(url: "https://www.example.com/", coordinates: "POINT(123, 456)")
      geo.valid?
      expect(geo.url).to eq("example.com")
    end
  end

  describe "custom methods" do
    describe ".find_by_ip_or_url" do
      let!(:geo1) { Geolocation.create!(ip: "192.168.1.1", coordinates: "POINT(123 456)", url: "example.com") }
      let!(:geo2) { Geolocation.create!(ip: "192.168.1.2", coordinates: "POINT(789 012)", url: "example.org") }

      it "finds by IP" do
        expect(Geolocation.find_by_ip_or_url("192.168.1.1")).to eq(geo1)
      end

      it "finds by normalized URL" do
        expect(Geolocation.find_by_ip_or_url("http://example.com")).to eq(geo1)
        expect(Geolocation.find_by_ip_or_url("https://example.org")).to eq(geo2)
      end

      it "normalizes URL for query" do
        expect(Geolocation.find_by_ip_or_url("example.com")).to eq(geo1)
        expect(Geolocation.find_by_ip_or_url("www.example.org")).to eq(geo2)
      end
    end
  end

  describe "custom_url_format validation" do
    it "allows valid URLs" do
      geo = Geolocation.new(url: "https://example.com", coordinates: "POINT(123, 456)")
      geo.valid?
      expect(geo.errors[:url]).to be_empty
    end

    it "adds error for invalid URLs" do
      geo = Geolocation.new(url: "invalid_url", coordinates: "POINT(123, 456)")
      geo.valid?
      expect(geo.errors[:url]).to include("must be a valid URL or domain name")
    end
  end
end
