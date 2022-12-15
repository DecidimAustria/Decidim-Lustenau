# frozen_string_literal: true

class AwsTranslator
  attr_reader :text, :source_locale, :target_locale, :resource, :field_name

  def initialize(resource, field_name, text, target_locale, source_locale)
    @resource = resource
    @field_name = field_name
    @text = text
    @target_locale = target_locale
    @source_locale = source_locale
  end

  def translate
    translation = aws_translate.

    Decidim::MachineTranslationSaveJob.perform_later(
      resource,
      field_name,
      target_locale,
      translation.text
    )
  end

  def aws_translate
    region = ENV['AWS_TRANSLATE_REGION'] || Rails.application.credentials.dig(:translator, :aws_region) || "eu-central-1"
    access_key_id = ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:translator, :aws_access_key_id)
    secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:translator, :aws_secret_access_key)
    aws_client = Aws::Translate::Client.new(
      region: region,
      credentials: Aws::Credentials.new(access_key_id, secret_access_key)
    )
    aws_client.translate_text(
      text: @text, # required
      # terminology_names: ["ResourceName"],
      source_language_code: @source_locale, # required
      target_language_code: @target_locale, # required
      settings: {
        formality: "FORMAL", # accepts FORMAL, INFORMAL
        profanity: "MASK", # accepts MASK
      }
    )
  end
end
