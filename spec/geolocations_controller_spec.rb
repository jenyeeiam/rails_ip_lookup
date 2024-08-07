# spec/controllers/geolocations_controller_spec.rb
require "rails_helper"
require "webmock/rspec"

RSpec.describe GeolocationsController, type: :controller do
  before(:each) do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  describe "GET #index" do
    it "returns a success response" do
      geolocation = Geolocation.create!(ip: "8.8.8.8", coordinates: "POINT(10 20)")
      get :index
      expect(response).to be_successful
      expect(JSON.parse(response.body)).not_to be_empty
    end

    context "when there is a database connection error" do
      before do
        allow(Geolocation).to receive(:find_by_ip_or_url).and_raise(ActiveRecord::ConnectionNotEstablished)
      end

      it "returns a service unavailable status" do
        get :show, params: { value: "8.8.8.8" }
        expect(response).to have_http_status(:service_unavailable)
        expect(JSON.parse(response.body)["error"]).to include("Database connection error")
      end
    end

    context "when there is a database statement error" do
      before do
        allow(Geolocation).to receive(:find_by_ip_or_url).and_raise(ActiveRecord::StatementInvalid)
      end

      it "returns a service unavailable status" do
        get :show, params: { value: "8.8.8.8" }
        expect(response).to have_http_status(:service_unavailable)
        expect(JSON.parse(response.body)["error"]).to include("Database connection error")
      end
    end
  end

  describe "GET #show" do
    context "when the value parameter is missing" do
      it "returns an error" do
        get :show, params: { value: " " }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("Parameter IP or URL is required")
      end
    end

    context "when an existing geolocation is found" do
      let!(:geolocation) { Geolocation.create!(ip: "7.7.7.7", coordinates: "POINT(10 20)") }

      it "returns the existing geolocation" do
        get :show, params: { value: "7.7.7.7" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["ip"]).to eq("7.7.7.7")
      end
    end

    context "when the response from ipstack is empty" do
      before do
        stub_request(:get, /api.ipstack.com/).to_return(
          status: 200,
          body: nil,
          headers: { "Content-Type" => "application/json" },
        )
      end

      it "returns an error" do
        get :show, params: { value: "8.8.8.8" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("Unable to fetch geolocation data")
      end
    end

    context "when a new geolocation is successfully saved" do
      before do
        stub_request(:get, /api.ipstack.com/).to_return(
          status: 200,
          body: { ip: "8.8.8.8", longitude: 10, latitude: 20 }.to_json,
          headers: { "Content-Type" => "application/json" },
        )
      end

      it "creates and returns the new geolocation" do
        get :show, params: { value: "8.8.8.8" }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["ip"]).to eq("8.8.8.8")
      end

      context "when saving a new geolocation fails" do
        before do
          stub_request(:get, /api.ipstack.com/).to_return(
            status: 200,
            body: { ip: "8.8.8.8", longitude: 10, latitude: 20 }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

          allow_any_instance_of(Geolocation).to receive(:save).and_return(false)
          allow_any_instance_of(Geolocation).to receive_message_chain(:errors, :full_messages).and_return(["Some error"])
        end

        it "returns an error when saving fails" do
          get :show, params: { value: "8.8.8.8" }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["errors"]).to include("Some error")
        end
      end
    end

    context "when the IP or URL is valid" do
      before do
        stub_request(:get, /api.ipstack.com/).to_return(
          status: 200,
          body: { ip: "8.8.8.8", longitude: 10, latitude: 20 }.to_json,
          headers: { "Content-Type" => "application/json" },
        )
      end

      it "fetches the geolocation from the service" do
        get :show, params: { value: "8.8.8.8" }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["ip"]).to eq("8.8.8.8")
      end
    end

    context "when the IP or URL is invalid" do
      it "returns an error" do
        get :show, params: { value: "invalid_value" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("Invalid IP address or URL format")
      end
    end
  end

  describe "POST #create" do
    context "when the IP or URL is valid" do
      before do
        stub_request(:get, /api.ipstack.com/).to_return(
          status: 200,
          body: { ip: "8.8.8.8", longitude: 10, latitude: 20 }.to_json,
          headers: { "Content-Type" => "application/json" },
        )
      end

      it "creates a new geolocation" do
        post :create, params: { ip: "8.8.8.8" }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["ip"]).to eq("8.8.8.8")
      end
    end

    context "when an existing geolocation is found" do
      let!(:geolocation) { Geolocation.create!(ip: "7.7.7.7", coordinates: "POINT(10 20)") }

      it "returns the existing geolocation" do
        post :create, params: { ip: "7.7.7.7" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["ip"]).to eq("7.7.7.7")
      end
    end

    context "when the IP or URL is invalid" do
      it "returns an error for invalid IP" do
        post :create, params: { ip: "999.999.999.999" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("A valid 'ip' or 'url' is required")
      end

      it "returns an error for invalid URL" do
        post :create, params: { url: "invalid_url" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("A valid 'ip' or 'url' is required")
      end
    end

    context "when the response from ipstack is empty" do
      before do
        stub_request(:get, /api.ipstack.com/).to_return(
          status: 200,
          body: nil,
          headers: { "Content-Type" => "application/json" },
        )
      end

      it "returns an error" do
        post :create, params: { ip: "8.8.8.8" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("Unable to fetch geolocation data")
      end
    end

    context "when a new geolocation is successfully saved" do
      before do
        stub_request(:get, /api.ipstack.com/).to_return(
          status: 200,
          body: { ip: "8.8.8.8", longitude: 10, latitude: 20 }.to_json,
          headers: { "Content-Type" => "application/json" },
        )
      end

      it "creates and returns the new geolocation" do
        post :create, params: { url: "example.com" }
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)["ip"]).to eq("8.8.8.8")
      end

      context "when saving a new geolocation fails" do
        before do
          stub_request(:get, /api.ipstack.com/).to_return(
            status: 200,
            body: { ip: "8.8.8.8", longitude: 10, latitude: 20 }.to_json,
            headers: { "Content-Type" => "application/json" },
          )

          allow_any_instance_of(Geolocation).to receive(:save).and_return(false)
          allow_any_instance_of(Geolocation).to receive_message_chain(:errors, :full_messages).and_return(["Some error"])
        end

        it "returns an error when saving fails" do
          post :create, params: { ip: "8.8.8.8" }
          expect(response).to have_http_status(:unprocessable_entity)
          expect(JSON.parse(response.body)["errors"]).to include("Some error")
        end
      end
    end
  end

  describe "DELETE #destroy" do
    context "when the geolocation exists" do
      let!(:geolocation) { Geolocation.create!(ip: "8.8.8.8", coordinates: "POINT(10 20)") }

      it "deletes the geolocation" do
        delete :destroy, params: { value: "8.8.8.8" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)["message"]).to eq("Geolocation deleted")
      end
    end

    context "when the geolocation is invalid" do
      it "returns an error" do
        delete :destroy, params: { value: "invalid_ip" }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)["error"]).to eq("Invalid IP address or URL format")
      end
    end

    context "when the geolocation doesn't exist" do
      it "returns an error" do
        delete :destroy, params: { value: "8.8.8.9" }
        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)["error"]).to eq("Geolocation not found")
      end
    end
  end
end
