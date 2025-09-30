# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    render json: {
      status: "ok",
      timestamp: Time.current.iso8601
    }, status: :ok
  end
end
