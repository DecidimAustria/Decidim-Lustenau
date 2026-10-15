# frozen_string_literal: true

class ReplaceAlternativeLandingBlocks < ActiveRecord::Migration[7.0]
  PLUGIN_MANIFESTS = %w[
    cover_full cover_half stack_horizontal stack_vertical tiles latest_blog_posts
    selected_consultations alternative_upcoming_meetings extra_title extra_information calendar
  ].freeze

  class Block < ActiveRecord::Base
    self.table_name = "decidim_content_blocks"
  end

  def up
    blocks = Block.where(scope_name: %w[homepage participatory_process_group_homepage],
                         manifest_name: PLUGIN_MANIFESTS).order(:id).lock.to_a
    unsupported = blocks.reject do |block|
      block.scope_name == "participatory_process_group_homepage" && block.manifest_name == "extra_information"
    end
    raise "Alternative Landing blocks need manual conversion: #{unsupported.map(&:id).join(', ')}" if unsupported.any?

    blocks.each do |block|
      if connection.select_value("SELECT 1 FROM decidim_content_block_attachments WHERE decidim_content_block_id = #{connection.quote(block.id)} LIMIT 1")
        raise "Alternative Landing block #{block.id} has attachments; preserve them before converting"
      end

      settings = block[:settings] || {}
      body = settings["body"] || {}
      raise "Unexpected translated body on block #{block.id}" unless body.is_a?(Hash)

      siblings = Block.where(decidim_organization_id: block.decidim_organization_id,
                             scope_name: block.scope_name, scoped_resource_id: block.scoped_resource_id)
      target = %w[html_1 html_2 html_3].find { |name| !siblings.exists?(manifest_name: name) }
      raise "No free HTML block slot for Alternative Landing block #{block.id}" unless target

      # Avoid callbacks from the removed plugin. Keep the original body/settings,
      # identity, publication state, timestamps and order for audit and recovery.
      block.update_columns(manifest_name: target, settings: settings.merge("html_content" => body))
    end
  end

  def down
    # Core HTML blocks also work with the previous application release. Reverting
    # edited content automatically could lose changes made after this migration.
    raise ActiveRecord::IrreversibleMigration, "Keep the converted core HTML blocks when rolling back application code; restore original block data from backup only if needed"
  end
end
