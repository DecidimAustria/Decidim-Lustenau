# Lustenau 0.29.7 upgrade and Alternative Landing removal

Prepared and validated locally on 2026-10-15. Verify staging deployment and acceptance separately from these local checks.

## Dependency changes

Decidim now locks the DecidimAustria `0.29-live` commit `56c8cb75f9bfd1e32a603e6ab05bfdc8e95473da`, version `0.29.7`. Shakapacker remains `7.2.3`. The copied JavaScript packages match the fork, and the application pins `graphql-ws` to `^5.16.2` so GraphiQL resolves the compatible version.

Removed `decidim-alternative_landing` and its three direct FullCalendar dependencies. No active application code imports them. The historical `_baks` directory was left untouched.

The source-specific Bundler update retained Rails `7.0.8.7`, Awesome `0.12.0`, Amazon Translate `0.3.2`, GoodJob `3.99.1`, and Sentry `5.23.0`. It changed or added 66 other non-Decidim gem versions. The pre-existing `arm64-darwin-25` platform and its native dependency entries are preserved. The fork also restores the mailer-logo host argument that was missing from Lustenau's old revision; test email logos and storage URLs on staging.

## Live plugin usage audit

Read-only queries used context `kubernetes-admin@cluster1` on 2026-10-15. Both environments still reported Decidim `0.29.3` and Alternative Landing `0.5.0`.

| Environment | Namespace | Plugin blocks |
| --- | --- | --- |
| Staging | `decidim-lustenau-staging` | None among the 12 homepage blocks; no process-group homepage blocks |
| Production | `decidim-lustenau-production` | One published `extra_information` block, ID 18, organization 1, process group 2, weight 2 |

Production group 2 is “dô und OK-JA!”. Block 18 has null settings and no attachments, so it has no saved text or images to recreate. All other audited blocks belong to core or Awesome. No remote data was changed.

Production has organization header snippets. The independent Decidim configuration already enables them, so removing the plugin should preserve them. Confirm this after deployment. Removing the plugin also removes its CSS and controller additions; visually check the homepage and both production process-group pages even though they have no other plugin blocks.

## Conversion migration

`20261015130000_replace_alternative_landing_blocks.rb` converts group `extra_information` blocks to the first available core HTML slot, `html_1` through `html_3`.

It preserves block IDs, organization/group ownership, publication state, weight, timestamps, and original settings. A translated `body` becomes `html_content`. Null settings become an empty HTML block, which matches the observed production data. The migration uses plain database records and does not depend on the removed plugin.

It stops if it finds another Alternative Landing block type, attachments, an unexpected body format, or no free HTML slot. Rails runs the migration transactionally. Investigate those failures rather than deleting the records to bypass them. Re-running the conversion is harmless once blocks have been converted.

The migration deliberately has no automatic `down`. Core HTML blocks work with the previous application release too, so an application rollback can leave converted blocks in place. Reversing edited content automatically could lose later changes. Restore original block data from a verified backup only if that is actually needed.

## Validation

- Ruby `3.2.8`, Node `18.17.1`; production-mode Zeitwerk check passed.
- Production asset precompilation passed with only asset-size warnings. It used dummy credentials and no customer database or storage access.
- PostgreSQL migration tests passed: 7 tests, 19 assertions. They cover multilingual text preservation, the empty production record shape, repeated execution, occupied HTML slots, transactional failure, unexpected plugin blocks, and attachment preservation.
- The plugin gem and content-block manifests are absent. A replacement core HTML cell rendered translated HTML successfully against the isolated database.
- npm reported 104 findings, including 3 critical. No broad audit fix was applied; dependency security maintenance remains separate from this plugin-removal validation.

Run the standalone migration tests against a disposable PostgreSQL database:

```bash
MIGRATION_TEST_DATABASE_URL='postgresql://USER@HOST/DISPOSABLE_DATABASE' \
  bundle exec ruby script/verify_alternative_landing_migration.rb
```

The tests create temporary tables and do not use Rails' normal test database. The local schema was also loaded into an isolated database for application-level checks.

## Pre-deployment backup

Staging CNPG backup `pre-0297-upgrade-20261015132001` completed on `2026-10-15T13:20:15Z`, backup ID `20261015T132014`, with no reported error. It covers the `postgres` cluster in `decidim-lustenau-staging`. Upload backups and restore testing were not part of this operation. Production needs its own fresh backup before promotion.

## Deployment sequence

1. Review and commit the upgrade, migration, validation script, and this document. Exclude generated assets and machine-specific Tailwind paths.
2. Create and verify a fresh CNPG backup in `decidim-lustenau-staging`; confirm upload recovery coverage. EMVI's backup does not cover Lustenau.
3. Push the reviewed revision to `main` for staging. The migration should find no plugin blocks there. Check the build and migration jobs, web and GoodJob rollouts, homepage/admin layout, login, proposals/comments, Awesome map, translations, uploads, email logos, and header snippets.
4. Before production, repeat the read-only block inventory and take a fresh production database backup. If plugin usage changed, review it before promotion. The converter handles the observed block; it intentionally refuses other plugin block types.
5. Promote the tested revision. Verify block 18 is now `html_1`, still belongs to group 2, and retains its publication state and weight. Confirm the public homepage and both group pages render without missing-cell or missing-pack errors. Check the content-block editor and header snippets.

A successful local build does not validate live mail delivery, storage URLs, authenticated flows, or the production visual layout. No production rollout is included in this preparation.
