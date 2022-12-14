# frozen_string_literal: true

# DeepL Translation service configuration
# you can also set the api key using an env var:
#  export DEEPL_AUTH_KEY="your-api-token"
# if Rails.env == "production"
#   DeepL.configure do |config|
#     config.auth_key = ENV['DEEPL_AUTH_KEY'] || Rails.application.credentials.dig(:translator, :api_key)
#     config.host = ENV['DEEPL_HOST'] || Rails.application.credentials.dig(:translator, :host)
#   end
# end