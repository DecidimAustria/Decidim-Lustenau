# frozen_string_literal: true

# Standalone fixture loader for an EMPTY disposable local database.
require "active_record"
require "open3"
require "bcrypt"
ActiveRecord::Base.establish_connection(adapter: "postgresql", host: "/private/tmp/decidim-0297-pg/socket", port: 55439, username: "decidim_upgrade", database: "lustenau_030_data_rehearsal")
connection = ActiveRecord::Base.connection
abort "Rehearsal database must be empty; no existing data will be replaced" unless connection.tables.empty?
baseline_ref = "9c772f97a1a14d4b6eded4233f78e0a2dd57bed4"
schema, status = Open3.capture2("git", "show", "#{baseline_ref}:db/schema.rb")
abort "Could not read the pre-upgrade schema" unless status.success?
ActiveRecord::Schema.verbose = false
seen = {}
source = schema.lines.reject do |line|
  next false unless line.strip.start_with?("add_foreign_key ")
  duplicate = seen[line]
  seen[line] = true
  duplicate
end.join
eval(source, TOPLEVEL_BINDING, "#{baseline_ref}:db/schema.rb")
c = ActiveRecord::Base.connection
c.create_table(:schema_migrations, id: false) { |t| t.string :version, null: false } unless c.table_exists?(:schema_migrations)
Open3.capture2("git", "ls-tree", "-r", "--name-only", baseline_ref, "db/migrate").first.lines.each do |file|
  version = File.basename(file.strip).split("_").first
  c.execute("INSERT INTO schema_migrations (version) VALUES (#{c.quote(version)}) ON CONFLICT DO NOTHING")
end
models = %w(organizations participatory_process_groups participatory_processes components content_blocks users).to_h do |name|
  [name, Class.new(ActiveRecord::Base) { self.table_name = "decidim_#{name}"; self.inheritance_column = :_type_disabled }]
end
org = models.fetch("organizations").create!(name: { de: "Upgradeprobe" }, host: "upgrade.example.org", default_locale: "de", available_locales: %w(de en), reference_prefix: "UPG", tos_version: Time.now, header_snippets: '<script>window.upgradeProbe = true;</script>')
group = models.fetch("participatory_process_groups").create!(id: 2, title: { de: "Upgradegruppe" }, description: { de: "Gruppe" }, decidim_organization_id: org.id)
process = models.fetch("participatory_processes").create!(slug: "upgradeprobe", title: { de: "Upgradeprobe" }, subtitle: { de: "Untertitel" }, short_description: { de: "Kurztext" }, description: { de: "<p>Hello</p>" }, decidim_organization_id: org.id, decidim_participatory_process_group_id: group.id, published_at: Time.now)
models.fetch("components").create!(manifest_name: "proposals", name: { de: "Ideen" }, participatory_space_id: process.id, participatory_space_type: "Decidim::ParticipatoryProcess", published_at: Time.now)
models.fetch("content_blocks").create!(id: 18, manifest_name: "html_1", scope_name: "participatory_process_group_homepage", scoped_resource_id: group.id, decidim_organization_id: org.id, settings: { html_content: { de: "<p>Erhaltener Inhalt</p>" } }, published_at: Time.now, weight: 2)
models.fetch("users").create!(type: "Decidim::User", name: "Upgrade User", nickname: "UpgradeUser", email: "upgrade-user@example.org", encrypted_password: BCrypt::Password.create("LocalRehearsalPassword123!"), decidim_organization_id: org.id, confirmed_at: Time.now, accepted_tos_version: Time.now, locale: "de")
puts "Seeded baseline organization, process, component, published HTML block, and mixed-case user"
