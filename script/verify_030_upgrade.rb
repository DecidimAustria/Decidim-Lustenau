# frozen_string_literal: true

# Run with Rails runner against the isolated, migrated synthetic-data rehearsal.
require "minitest/autorun"
require "json"

config = ActiveRecord::Base.connection_db_config.configuration_hash
unless Rails.env.test? && config[:database] == "lustenau_030_data_rehearsal" && config[:host] == "/private/tmp/decidim-0297-pg/socket"
  abort "Use the isolated lustenau_030_data_rehearsal database in test mode only"
end

Rails.application.load_tasks

# Reuse the separately verified production build for the layout smoke test.
# Test-mode webpack injects CSS into JavaScript instead of writing CSS packs.
manifest = Rails.root.join("public/decidim-packs/manifest.json")
abort "Compile production assets before running these checks" unless manifest.exist?
Shakapacker.config.define_singleton_method(:compile?) { false }
Shakapacker.config.define_singleton_method(:manifest_path) { manifest }

class Upgrade030Test < Minitest::Test
  def setup
    ActiveRecord::Base.connection.begin_transaction(joinable: false)
    @organization = Decidim::Organization.find_by!(host: "upgrade.example.org")
    @process = Decidim::ParticipatoryProcess.find_by!(slug: "upgradeprobe")
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
    RequestStore.store[:toggle_machine_translations] = nil
  end

  def teardown
    RequestStore.store[:toggle_machine_translations] = nil
    ActiveRecord::Base.connection.rollback_transaction
  end

  def invoke_task(name, *args)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*args)
  end

  def controller_for(url)
    controller = Decidim::ApplicationController.new
    controller.set_request!(ActionDispatch::Request.new(Rack::MockRequest.env_for(url)))
    organization = @organization
    controller.define_singleton_method(:current_organization) { organization }
    controller
  end

  def translation_link(url, toggle:)
    RequestStore.store[:toggle_machine_translations] = toggle
    cell = Cell::ViewModel.cell("decidim/translation_bar", @organization, context: { controller: controller_for(url) })
    cell.define_singleton_method(:button_text) { "Original" }
    Nokogiri::HTML.fragment(cell.link).at_css("a")["href"]
  end

  def test_translation_toggle_on_error_url_without_query
    url = "http://upgrade.example.org/missing"
    assert_equal url, translation_link(url, toggle: true)
  end

  def test_normal_translation_links_keep_other_parameters
    assert_equal "http://upgrade.example.org/processes?page=2&", translation_link("http://upgrade.example.org/processes?page=2&toggle_translations=true", toggle: true)
    assert_equal "http://upgrade.example.org/processes?toggle_translations=true", translation_link("http://upgrade.example.org/processes", toggle: false)
  end

  def test_empty_taxonomy_conversion
    invoke_task("decidim:taxonomies:make_plan")
    file = Rails.root.join("tmp/taxonomies/upgrade.example.org_plan.json")
    assert file.exist?, "taxonomy plan was not written"
    invoke_task("decidim:taxonomies:import_plan", file.to_s)
    invoke_task("decidim:taxonomies:update_metrics", file.to_s)
    assert_equal 0, Decidim::Taxonomy.count
    assert_equal 0, Decidim::TaxonomyFilter.count
  end

  def test_lowercase_nickname_task
    user = Decidim::User.find_by!(email: "upgrade-user@example.org")
    assert_equal "UpgradeUser", user.nickname
    invoke_task("decidim:upgrade:fix_nickname_casing")
    assert_equal "upgradeuser", user.reload.nickname
  end

  def test_converted_html_block_survives_upgrade
    block = Decidim::ContentBlock.find(18)
    assert_equal "html_1", block.manifest_name
    assert_equal 2, block.scoped_resource_id
    assert_equal 2, block.weight
    assert block.published_at
    html = Cell::ViewModel.cell("decidim/content_blocks/html", block, context: { controller: controller_for("http://upgrade.example.org/") }).call
    assert_includes html, "Erhaltener Inhalt"
  end

  def test_amazon_translation_job_persists_html
    client = Aws::Translate::Client.new(region: "eu-central-1", stub_responses: true)
    client.stub_responses(:translate_text, translated_text: "Hallo", source_language_code: "en", target_language_code: "de")
    translator = Decidim::AmazonTranslate::AmazonTranslator.new(@process, :description, @process.description.fetch("de").dup, "de", "en")
    translator.define_singleton_method(:aws_client) { client }
    translator.translate
    jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select { |job| job[:job] == Decidim::MachineTranslationSaveJob }
    assert_equal 1, jobs.count
    args = ActiveJob::Arguments.deserialize(jobs.first[:args])
    Decidim::MachineTranslationSaveJob.perform_now(*args)
    assert_equal "<p>Hallo</p>", @process.reload.description.dig("machine_translations", "de")
  end

  def test_modules_and_schema_are_ready
    assert_equal "0.30.9", Decidim.version
    assert_equal "0.13.2", Gem.loaded_specs.fetch("decidim-decidim_awesome").version.to_s
    assert_includes Decidim.component_manifests.map(&:name), :awesome_map
    refute ActiveRecord::Base.connection.migration_context.needs_migration?
  end

  def test_public_homepage_and_saved_header_snippet
    previous = Decidim.enable_html_header_snippets
    Decidim.enable_html_header_snippets = true
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host!(@organization.host)
    session.get("/")
    assert_equal 200, session.response.status
    assert session.response.body.include?("window.upgradeProbe = true;"), "saved header snippet was not rendered"
  ensure
    Decidim.enable_html_header_snippets = previous
  end

  def test_release_cleanup_tasks_keep_active_records
    %w(
      decidim_proposals:upgrade:set_categories
      decidim:upgrade:clean:clean_deleted_users
      decidim:upgrade:clean:invalid_private_exports
      decidim:upgrade:fix_action_log
      decidim:upgrade:clean:remove_private_exports_attachments
      decidim:upgrade:remove_deleted_users_left_data
      decidim:upgrade:fix_deleted_private_follows
      decidim:upgrade:attachments_cleanup
    ).each { |task| invoke_task(task) }
    assert Decidim::User.exists?(email: "upgrade-user@example.org")
    assert Decidim::ParticipatoryProcess.exists?(@process.id)
    assert Decidim::ContentBlock.exists?(18)
  end
end
