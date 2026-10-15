# frozen_string_literal: true

# Run with bundle exec ruby and MIGRATION_TEST_DATABASE_URL pointing at a disposable PostgreSQL database.
require "active_record"
require "minitest/autorun"
require_relative "../db/migrate/20261015130000_replace_alternative_landing_blocks"

ActiveRecord::Base.establish_connection(ENV.fetch("MIGRATION_TEST_DATABASE_URL"))

class ReplaceAlternativeLandingBlocksTest < Minitest::Test
  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table(:decidim_content_blocks, temporary: true) do |t|
      t.integer :decidim_organization_id
      t.string :scope_name
      t.integer :scoped_resource_id
      t.string :manifest_name
      t.jsonb :settings
      t.datetime :published_at
      t.integer :weight
      t.timestamps
    end
    @connection.create_table(:decidim_content_block_attachments, temporary: true) do |t|
      t.integer :decidim_content_block_id
    end
    ReplaceAlternativeLandingBlocks::Block.reset_column_information
  end

  def teardown
    @connection.execute("DROP TABLE IF EXISTS pg_temp.decidim_content_block_attachments")
    @connection.execute("DROP TABLE IF EXISTS pg_temp.decidim_content_blocks")
  end

  def block(manifest = "extra_information", settings: nil, **attributes)
    ReplaceAlternativeLandingBlocks::Block.create!({
      decidim_organization_id: 1, scope_name: "participatory_process_group_homepage",
      scoped_resource_id: 2, manifest_name: manifest, settings: settings,
      published_at: Time.utc(2020), weight: 2
    }.merge(attributes))
  end

  def migrate
    ActiveRecord::Base.transaction { ReplaceAlternativeLandingBlocks.new.up }
  end

  def test_preserves_translations_settings_and_block_identity
    record = block(settings: {"body" => {"de" => "<p>Hallo</p>", "en" => "<p>Hello</p>"}, "columns" => 6})
    original = record.attributes
    migrate
    record.reload
    assert_equal "html_1", record.manifest_name
    assert_equal original["settings"]["body"], record[:settings]["html_content"]
    assert_equal original["settings"], record[:settings].except("html_content")
    assert_equal original.except("settings", "manifest_name"), record.attributes.except("settings", "manifest_name")
  end

  def test_empty_production_shape_and_repeat_run
    record = block
    migrate
    assert_equal({"html_content" => {}}, record.reload[:settings])
    migrate
    assert_equal "html_1", record.reload.manifest_name
  end

  def test_uses_free_slot_within_the_same_organization_and_group
    existing = block("html_1", settings: {"html_content" => {"de" => "Existing"}})
    other_group = block("html_2", scoped_resource_id: 3)
    record = block
    migrate
    assert_equal "html_2", record.reload.manifest_name
    assert_equal "Existing", existing.reload[:settings]["html_content"]["de"]
    assert_equal "html_2", other_group.reload.manifest_name
  end

  def test_full_slots_roll_back_prior_conversions
    first = block(scoped_resource_id: 1)
    %w[html_1 html_2 html_3].each { |name| block(name) }
    blocked = block
    assert_raises(RuntimeError) { migrate }
    assert_equal "extra_information", first.reload.manifest_name
    assert_equal "extra_information", blocked.reload.manifest_name
  end

  def test_unexpected_plugin_block_prevents_all_conversion
    convertible = block
    block("cover_full", scope_name: "homepage", scoped_resource_id: nil)
    assert_raises(RuntimeError) { migrate }
    assert_equal "extra_information", convertible.reload.manifest_name
  end

  def test_attachments_are_not_silently_orphaned
    record = block
    @connection.execute("INSERT INTO decidim_content_block_attachments (decidim_content_block_id) VALUES (#{record.id})")
    assert_raises(RuntimeError) { migrate }
    assert_equal "extra_information", record.reload.manifest_name
    assert_equal 1, @connection.select_value("SELECT count(*) FROM decidim_content_block_attachments")
  end

  def test_nontranslated_body_is_rejected
    record = block(settings: {"body" => "unexpected"})
    assert_raises(RuntimeError) { migrate }
    assert_equal "extra_information", record.reload.manifest_name
  end
end
