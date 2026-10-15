# frozen_string_literal: true

# Generate /api/docs in the image from the installed schema.
Rake::Task["assets:precompile"].enhance(["decidim_api:generate_docs"])
