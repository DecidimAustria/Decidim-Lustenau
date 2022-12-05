Raven.configure do |config|
  config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
  config.release = ENV['GIT_REV'] if ENV.has_key?('GIT_REV') && ENV['GIT_REV'].present?
end

