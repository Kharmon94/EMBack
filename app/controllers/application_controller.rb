class ApplicationController < ActionController::API
  # Include Devise helpers for API mode
  include ActionController::MimeResponds
  
  # Configure Devise parameters
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  protected
  
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:wallet_address, :role])
    devise_parameter_sanitizer.permit(:account_update, keys: [:wallet_address])
  end
end
