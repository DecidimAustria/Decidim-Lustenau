# frozen_string_literal: true

source "https://rubygems.org"

ruby "3.3.13"
DECIDIM_VERSION = { git: "https://github.com/DecidimAustria/decidim", branch: 'security/0.30-concurrent-ruby-20261110' }

gem "decidim", DECIDIM_VERSION

# Keep all bundled framework components on the same patched Git revision.
%w[
  decidim-accountability
  decidim-admin
  decidim-api
  decidim-assemblies
  decidim-blogs
  decidim-budgets
  decidim-comments
  decidim-core
  decidim-debates
  decidim-forms
  decidim-generators
  decidim-meetings
  decidim-pages
  decidim-participatory_processes
  decidim-proposals
  decidim-sortitions
  decidim-surveys
  decidim-system
  decidim-verifications
].each do |component|
  gem component, DECIDIM_VERSION.merge(require: false)
end
gem "decidim-decidim_awesome", "~> 0.13.0"
# gem "decidim-conferences", DECIDIM_VERSION
#gem "decidim-consultations", DECIDIM_VERSION
# gem "decidim-elections", DECIDIM_VERSION
# gem "decidim-initiatives", DECIDIM_VERSION
# gem "decidim-templates", DECIDIM_VERSION
gem "decidim-amazon_translate"
#gem "decidim-term_customizer", git: "https://github.com/mainio/decidim-module-term_customizer", branch: 'main'
#gem "decidim-term_customizer", git: "https://github.com/mainio/decidim-module-term_customizer", branch: 'release/0.28-stable'

# Get latest CLDR changes to fix bug with count :zero
# remove when this commit gets released in a version https://github.com/ruby-i18n/i18n/commit/c78ca610b64712037e5726adeaf7b84fa96eded9
gem "i18n"#, git: "https://github.com/ruby-i18n/i18n", branch: "master"

gem 'aws-sdk-s3'
gem "aws-sdk-translate", '~> 1'

#gem "deepl-rb", require: "deepl"

gem "bootsnap", "~> 1.3"

# Fix logger error by defining the concurrent-ruby version
#gem 'concurrent-ruby', '1.3.4'

gem "puma", ">= 5.0.0"

#gem "faker", "~> 3.2"

gem 'hiredis'
gem "redis", :require => ["redis", "redis/connection/hiredis"]

gem "stackprof"

gem "sentry-ruby"
gem "sentry-rails"

#gem 'sidekiq', '<7'
gem 'virtus', '~> 1.0.5'
gem "wicked_pdf", "~> 2.1"

gem "rectify", "~> 0.13.0"

group :development, :test do
  gem "byebug", "~> 11.0", platform: :mri

  gem "brakeman", "~> 6.0"
  gem "net-imap", "~> 0.5.15"
  gem "net-pop", "~> 0.1.1"
  gem "net-smtp", "~> 0.5.0"
  gem "decidim-dev", DECIDIM_VERSION
end

group :development do
  gem "easy_translate", "~> 0.5.1"
  gem "letter_opener_web", "~> 2.0"
  gem "listen", "~> 3.1"
  gem "solargraph"
  gem "web-console", "~> 4.2"
end

group :production do
end

gem "good_job", "~> 3.27"
