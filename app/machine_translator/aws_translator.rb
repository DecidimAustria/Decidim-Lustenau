# frozen_string_literal: true

# MachineTranslation module that uses the synchronous AWS Translation service
class AwsTranslator
  attr_reader :text, :source_locale, :target_locale, :resource, :field_name

  def initialize(resource, field_name, text, target_locale, source_locale)
    @resource = resource
    @field_name = field_name
    @text = text
    @target_locale = target_locale
    @source_locale = source_locale
    @region = ENV['AWS_TRANSLATE_REGION'] || Rails.application.credentials.dig(:translator, :aws_region) || "eu-central-1"
    access_key_id = ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:translator, :aws_access_key_id)
    secret_access_key = ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:translator, :aws_secret_access_key)
    @credentials = Aws::Credentials.new(access_key_id, secret_access_key)
  end

  def translate
    Sentry.with_scope do |scope|
      scope.set_context(
        'translation',
        {
          text: @text,
          source_locale: @source_locale,
          target_locale: @target_locale,
          field_name: @field_name,
          resource: @resource
        }
      )
      Sentry.capture_message("Running translate")
    end
    return if @text.blank?

    # remove base64 encoded images if they exist
    @text.gsub!(%r{<img src=\"data:image/png;base64,.*>}, '')
    return if @text.bytesize > 10_000

    translation = aws_translate

    Sentry.with_scope do |scope|
      scope.set_context(
        'translation',
        {
          text: translation.translated_text,
          source_locale: source_locale,
          target_locale: target_locale,
          field_name: field_name,
          resource: resource,
          at_source_locale: @source_locale,
          at_target_locale: @target_locale,
          at_field_name: @field_name,
          at_resource: @resource
        }
      )
      Sentry.capture_message("Creating MachineTranslationSaveJob with translated text")
    end
    Decidim::MachineTranslationSaveJob.perform_later(
      @resource,
      @field_name,
      @target_locale,
      translation.translated_text
    )
  end

  def aws_translate
    Sentry.with_scope do |scope|
      scope.set_context(
        'translation',
        {
          text: @text,
          source_locale: @source_locale,
          target_locale: @target_locale
        }
      )
      Sentry.capture_message("Contacting AWS Translate") # will be tagged with `my_tag: "my value"`
    end

    aws_client = Aws::Translate::Client.new(region: @region, credentials: @credentials)
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
