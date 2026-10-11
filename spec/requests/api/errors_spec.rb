# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API error responses", type: :request do
  let(:api) do
    Class.new(Grape::API) do
      include API::V1::Defaults

      get "/missing" do
        raise ActiveRecord::RecordNotFound, "Record not found"
      end

      get "/invalid" do
        record = Game.new
        record.errors.add(:name, "is invalid")
        raise ActiveRecord::RecordInvalid, record
      end
    end
  end

  it "returns a JSON 404 for a missing record" do
    response = Rack::MockRequest.new(api).get("/api/v1/missing")

    expect(response.status).to eq(404)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq("error" => "Record not found")
  end

  it "returns a JSON 422 for an invalid record" do
    response = Rack::MockRequest.new(api).get("/api/v1/invalid")

    expect(response.status).to eq(422)
    expect(response.media_type).to eq("application/json")
    expect(JSON.parse(response.body).fetch("error")).to include("Name is invalid")
  end
end
