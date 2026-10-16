# Lustenau 0.30.9 upgrade

Prepared and validated on 2026-10-15 on `upgrade/lustenau-0.30`, then authorized for commit and push to `main` for Auto DevOps staging. A fresh staging database backup completed before publication (see below). Verify the pipeline and deployed revision separately; production remains on the accepted 0.29.7 deployment.

## Dependencies and deployment prerequisite

The application now locks Decidim `0.30.9` from DecidimAustria's `0.30-live`, revision `f9239d0d26e138f6def204536bf9a12e98f9e8ed`. That revision is upstream `v0.30.9` plus the Shakapacker 7.2 dependency patch and aligned lockfiles. The old icon URL and Polish framework patches are omitted. Lustenau's staging and production organizations do not currently enable Polish, so no application locale override was added here.

Framework `0.30-live` was published to DecidimAustria on 2026-10-15, and its remote SHA was verified as `f9239d0d26e138f6def204536bf9a12e98f9e8ed` before the application push. Local resolution initially used a Bundler override, then the Git revision was cached and the override removed. The final Gemfile/lockfile use the portable GitHub source, with no local path dependency.

Ruby is pinned to `3.3.12` in the Gemfile, lockfile, `.ruby-version`, and `mise.toml`. It satisfies the target's Ruby 3.3 requirement and includes the [3.3.12 security fixes](https://www.ruby-lang.org/en/news/2026/07/16/ruby-3-3-12-released/). The current [Heroku support reference](https://devcenter.heroku.com/articles/ruby-support-reference) lists this version; confirm the actual CI builder resolves it during staging. Node `22.14.0` is aligned in `mise.toml` and package engines.

Awesome moves from `0.12.0` to `0.13.2`, with the Gemfile constrained to `~> 0.13.0`. Its declared compatibility covers Decidim 0.30. Amazon Translate `0.3.2`, Rails `7.0.8.7`, GoodJob `3.99.1`, Sentry `5.23.0`, and Shakapacker `7.2.3` are retained. The conservative source update changed or added 31 non-Decidim gem versions, including the required Ransack/validation/mail dependencies. `net-smtp` now requires `~> 0.5.0`, matching core; `net-imap` uses the patched Ruby 3.3 series `~> 0.4.25`.

No Terraform change is required for these repository-pinned runtime versions. The existing Heroku Node/Ruby/Procfile buildpack sequence and Shakapacker CI-variable configuration are retained. `projects_tf` still configures only `db:migrate` for the migration job; it does not run the one-time tasks below.

## Migrations and generated files

The generator copied 42 new migrations, including taxonomy structures, soft-delete fields, and Hashcash storage. All passed against the committed old schema in an isolated PostgreSQL 14 database. They also passed with synthetic existing organization/process/component/user records and a published core HTML block matching the previous Alternative Landing conversion.

The generator patched 543 historical migration files. Restored 493 changes that only added a timestamp comment and blank lines, retaining 50 substantive compatibility fixes. Those fixes include current time formatting, nickname method arguments, and migration-local model definitions. Do not discard the remaining old-migration changes as generated noise.

The previous committed schema contained three duplicate foreign-key declarations that prevented a direct schema load. The disposable rehearsal removed duplicate declarations while loading that snapshot. The regenerated `db/schema.rb` represents the migrated rehearsal. This did not remove constraints from either live database. The rehearsal used synthetic data, not a production database copy, so it does not establish compatibility with every live record.

Removed generated API HTML/CSS, service-worker archives, and machine-specific Tailwind configuration from Git tracking. `.gitignore` now covers those paths. `lib/tasks/api_documentation.rake` generates `/api/docs` during `assets:precompile`, matching nightly's build approach. The production build regenerated the documentation, including the new taxonomy API. These removals account for most deleted lines in the review diff; they do not remove the deployed API documentation.

## Application compatibility

- Preserved the pre-existing HERE v3 initializer edit exactly. The older default fallback already used v3. Check real map images and credentials on staging; local compilation did not contact HERE.
- Added `translation_bar_query_guard.rb` for the error-page crash found after 0.29.7. When translation state is enabled but the URL has no query, it returns the original link instead of calling `gsub` on nil. Other query/toggle behavior delegates to upstream. The framework fork contains no corresponding override.
- The published `html_1` group block survives the migration with its owner, weight, publication state, and translated content intact in the synthetic rehearsal.
- Existing custom header/footer templates and the Amazon Translate integration boot and render with the upgraded bundle. Production has two inline Matomo-related script snippets. With the existing header-snippet feature enabled, the target bundle renders a saved script in the local public-layout check. No sanitization bypass was added. Verify Matomo and consent behavior in the actual browser after deployment; generic release warnings alone do not establish how these saved snippets behave.
- The previously observed SVG missing-asset error response is not covered by the translation-bar guard. Check the browser network panel for missing assets and verify error handling separately on staging.

## Validation

- Ruby `3.3.12`, Node `22.14.0`; bundle install/check passed with the Git source and the temporary override removed.
- Production-mode Zeitwerk passed. Production assets actually compiled, with Sass deprecation messages and two webpack size warnings. API documentation regenerated. The build used dummy credentials and an unreachable database address.
- Empty-schema and synthetic-data migration rehearsals passed all 42 new migrations. Both rehearsal databases are isolated on a local PostgreSQL socket.
- Focused checks passed: **9 tests, 26 assertions**. They cover the nil-query guard, normal toggle URLs, empty taxonomy import/metrics, lowercase nicknames, HTML block preservation, Amazon translation enqueue/persistence, module/schema readiness, public rendering/header snippets, and execution of release cleanup tasks while retaining active records.
- The synthetic cleanup fixture has no deleted accounts or private export attachments; the checks validate task availability and active-record preservation, not every cleanup branch.
- npm reports 101 findings, including 3 critical. No broad audit fix was applied.

The focused checks require the migrated synthetic fixture and the production asset manifest. `script/seed_030_rehearsal.rb` loads the pre-upgrade schema from app commit `9c772f97`, normalizes the duplicate foreign-key declarations, records that revision's existing migrations, and seeds synthetic records. It connects only to the named local rehearsal database and refuses to operate unless it is empty. With the isolated PostgreSQL service running, create an empty `lustenau_030_data_rehearsal` database and run the loader with `bundle exec ruby script/seed_030_rehearsal.rb`, then run `db:migrate` with the test database URL below. Do not run the loader with Rails runner, which boots the application first.

The verification uses Rails' test mail/job adapters and a stubbed AWS client:

```sh
DISABLE_SPRING=1 SENTRY_DSN='' RAILS_ENV=test AWS_EC2_METADATA_DISABLED=true \
AWS_REGION=eu-central-1 AWS_ACCESS_KEY_ID=local-test AWS_SECRET_ACCESS_KEY=local-test \
DATABASE_URL='postgresql://decidim_upgrade@/lustenau_030_data_rehearsal?host=/private/tmp/decidim-0297-pg/socket&port=55439' \
bundle exec rails runner script/verify_030_upgrade.rb
```

The script refuses customer databases and wraps each test's changes in a transaction. It reuses the separately compiled production asset manifest for layout tests rather than generating test-mode CSS.

## Live preflight inventory

Read-only checks used context `kubernetes-admin@cluster1` on 2026-10-15.

| Data | Staging | Production |
| --- | --- | --- |
| Categories / scopes / areas | 0 / 0 / 0 | 0 / 0 / 0 |
| Process types / assembly types | 0 / 0 | 0 / 0 |
| Processes / assemblies | 4 / 0 | 10 / 0 |
| User groups | 0 | 0 |
| Mixed-case nicknames | 0 | 12 |
| Case-insensitive nickname collision groups | 0 | 0 |
| Metrics records | 0 | 0 |
| Enabled organization OAuth providers | None | None |

Recheck immediately before deployment. The taxonomy plan should be empty, but generate and inspect it per environment rather than treating an old count as proof. Production's nickname task should update 12 users if the inventory is unchanged. No collision groups were found; inspect task output for validation failures or unexpected renamed users.

## Staging rollout

### BuildKit trial after the failed CNB build

The upgrade push started pipeline 6742, but [build job 26882](https://gitlab.webface.at/mitgestalten/decidim-lustenau/-/jobs/26882) failed before Ruby installation: the configured Heroku-20 builder received HTTP 403 downloading Ruby 3.3.12. This did not deploy the upgrade.

Branch `ci/lustenau-buildkit` initially tested `gitlab.webface.at/components/rails-deploy/pipeline@buildkit` with Ruby 3.3.12, Node 22.14.0, feature-branch builds enabled and `deploy: false`. Decidim 0.30.9 requires Ruby `~> 3.3.0`; the component example's Ruby 3.4.7 is unsuitable here. The component ref resolved to `b617c78fc4d5c9ce4710db3c43ffd9f093a43e4c` during preparation and follows subsequent branch updates.

GitLab CI lint passed without warnings. Local inspection of the generated child pipeline confirmed a required rootless BuildKit build and no deployment template/jobs. Production-mode boot with dummy build credentials, an unreachable database and `STORAGE_PROVIDER=local` passed. The storage setting now honors that variable, retaining MinIO as the default, so compilation does not require customer storage credentials. The component uses its bundled Dockerfile; no application runtime secrets are forwarded to the image build.

The first trial, parent pipeline 6743 / child 6744 / build job 26896, installed Ruby, the complete production bundle and npm packages successfully. Asset compilation then failed because Shakapacker 7.2.3 defaulted to `yarn`, which the npm-based image does not install. The application boot now defaults `SHAKAPACKER_USE_PACKAGE_JSON_GEM=true` and `PACKAGE_JSON_FALLBACK_MANAGER=npm`, preserving explicit environment overrides. This makes the build independent of the old buildpack-forwarding settings. A forced local production webpack compilation with Yarn excluded from `PATH` passed in 34.6 seconds with two size warnings.

The corrected build, pipeline 6753 / child 6754 / job 26931, succeeded on application commit `d01c68e0`. It compiled production assets, generated API documentation and published the image and registry cache. The tested Dockerfile matches component revision `151c717854ebbaabdec0ffd4a035e978ec628f21`, which fixes copying local npm packages before installation. The uncached job took 39 minutes 10 seconds, including about eight minutes for cache export. The image digest is `sha256:1ddedc0f7ff4bfb843eedb6196f16293bfca217608f098b538137bd704cbe911`. The 71 component tests passed; full MR scan acceptance is separate.

### BuildKit deployment commands

The user authorized preparing and publishing the deployment changes on 2026-10-15. The application changes are part of `ci/lustenau-buildkit` and MR !88. The Terraform prerequisite is a separate commit, `5128185c0287ef06934ed26689a31895e0e8d246`, on `projects_tf/ci/lustenau-buildkit`:

- `projects_tf/decidim-lustenau.tf` overrides `DB_MIGRATE` with `RAILS_ENV=production bundle exec rails db:migrate`. The shared module default still serves CNB installations. A full refreshed OpenTofu plan showed exactly one in-place update, `module.decidim_lustenau.gitlab_project_variable.DB_MIGRATE`, and no other resource changes. No apply was performed.
- Both `.gitlab/auto-deploy-values-staging.yaml` and `.gitlab/auto-deploy-values.yaml` start the worker with `bundle exec good_job start`. The old `/cnb/lifecycle/launcher` does not exist in the BuildKit image.
- `.gitlab-ci.yml` now selects `deploy: true`. GitLab CI lint accepted both the component include and generated deployment child without warnings: staging is automatic and all four production rollout jobs are manual. MR pipelines still omit deployment jobs even with this input enabled.

The immutable image was also tested locally with disposable PostgreSQL 16 and Redis 6 Sentinel services on an internal Docker network, without customer data, cluster credentials or external service access. Production schema loading and the exact migration command passed. `bundle exec good_job start` served HTTP 200 on both `/status/started` and `/status/connected`. The default web entrypoint served the system login page and a compiled asset with HTTP 200 as UID 1000; the generated API documentation file was present. The test used `DECIDIM_FORCE_SSL=false`, matching the existing Helm values, and local storage. All test containers, volumes and the network were removed. This checks the runtime commands against a fresh current schema; it does not repeat the existing-data upgrade rehearsal, test Garage uploads, or establish Kubernetes rollout acceptance.

Apply the reviewed infrastructure change before merging/pushing the application changes to `main`. The worker command changes take effect with their corresponding Helm rollout. Main still has its previous Auto DevOps setup until the application branch is integrated. Use the tested BuildKit image for migrations and workers; an older CNB image can still require its launcher.

After rollout, validate web requests, assets/API docs, database and storage access, worker probes and job processing, then complete the release tasks. The existing web liveness/readiness probes are disabled; a successful Helm rollout alone does not establish HTTP health. The database/data conversion rehearsals above used isolated synthetic records, not a production copy.

### Backup and rollout checklist

CNPG backup `pre-0309-upgrade-20261015180706` completed successfully at `2026-10-15T18:07:08Z`, backup ID `20261015T180707`, in context `kubernetes-admin@cluster1`, namespace `decidim-lustenau-staging`, cluster `postgres`, using `barmanObjectStore`. No backup error was reported. This is a database backup; this step did not create an upload backup or test a restore. The live one-time tasks below have not been run.

1. Framework publication and the fresh staging database backup are complete. Commit the reviewed application branch, including the existing map edit. Confirm upload/recovery coverage separately before any file-removing tasks.
2. Push/merge the reviewed application revision to `main` when ready for Auto DevOps staging. Confirm Ruby/Node selection, asset/API-doc generation, schema migration success, and ready web/GoodJob pods in `decidim-lustenau-staging`.
3. Run the relevant one-time tasks below in staging. Use explicit context/namespace and the new image. Preserve the taxonomy plan and result files outside the pod; all taxonomy commands must use the same reviewed files.
4. Accept the homepage, both process-group pages, group HTML editor, login/account flows, proposals/comments and filtering, Awesome editors/map/iframe, translations through GoodJob, uploads/downloads, email logos, HERE map images, `/api/docs`, and the translation-enabled error-page case. Check logs and missing assets.

After deploying the BuildKit image, use `bundle exec rails TASK` in container `auto-deploy-app`. Existing CNB pods still need their launcher. For example, staging plan generation on the new image is:

```sh
kubectl --context kubernetes-admin@cluster1 --namespace decidim-lustenau-staging \
  exec deployment/staging -c auto-deploy-app -- \
  bundle exec rails decidim:taxonomies:make_plan
```

### One-time tasks per environment

Review the cumulative [0.30.0](https://github.com/decidim/decidim/releases/tag/v0.30.0), [0.30.1](https://github.com/decidim/decidim/releases/tag/v0.30.1), [0.30.4](https://github.com/decidim/decidim/releases/tag/v0.30.4), [0.30.5](https://github.com/decidim/decidim/releases/tag/v0.30.5), and [0.30.7](https://github.com/decidim/decidim/releases/tag/v0.30.7) instructions. The other patch notes were also checked. Execute these once against each environment after its schema migration, with that environment's backup and reviewed data:

```sh
bin/rails decidim:taxonomies:make_plan
# Review and preserve tmp/taxonomies/*_plan.json before import.
bin/rails decidim:taxonomies:import_all_plans
bin/rails decidim:taxonomies:update_all_metrics
bin/rails decidim_proposals:upgrade:set_categories
bin/rails decidim:upgrade:fix_nickname_casing
bin/rails decidim:upgrade:fix_action_log
bin/rails decidim:upgrade:clean:clean_deleted_users
bin/rails decidim:upgrade:clean:invalid_private_exports
bin/rails decidim:upgrade:clean:remove_private_exports_attachments
bin/rails decidim:upgrade:remove_deleted_users_left_data
bin/rails decidim:upgrade:fix_deleted_private_follows
bin/rails decidim:upgrade:attachments_cleanup
```

The export/attachment/deleted-user tasks remove data or files, and nickname conversion can rename accounts. They were rehearsed only locally, not executed remotely during preparation. Preserve logs and verify affected counts. Historical meeting-attendance metric rebuilding is optional; select its start date from actual meeting history if those metrics are wanted. No organization OAuth provider is enabled, so social-login icon migration is currently inapplicable. No `data:migrate` task is required by the inspected 0.30 patch instructions; assess it separately for 0.31.

## Production promotion and recovery

After staging acceptance, take a separate fresh backup for `decidim-lustenau-production`, confirm upload recovery coverage, and promote the tested image using the existing manual production rollout. The production Deployment is `production`; do not reuse staging's namespace or taxonomy files.

Run and verify the one-time tasks against production immediately after its schema migration, then repeat acceptance checks, including the 12 nickname conversions and Matomo. Keep the production schema/plan/task results and image revision in the deployment record.

This upgrade adds and removes schema columns and performs data conversions. Reverting only the image can leave the old code incompatible with the database. Recovery may require restoring a coordinated database/upload backup, accounting for writes since the backup. The rehearsal does not establish a complete automatic rollback path.
