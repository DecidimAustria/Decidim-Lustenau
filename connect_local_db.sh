#!/bin/bash

export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_USER=gitpod
unset DATABASE_PASSWORD
export DATABASE_DB=postgres
export DATABASE_URL=postgresql://gitpod@localhost
export PGHOSTADDR=127.0.0.1
export DECIDIM_HOST="3000-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST"
export DECIDIM_FOLLOW_HTTP_X_FORWARDED_HOST=true
# export DECIDIM_FORCE_SSL=false
# export DECIDIM_ALLOW_OPEN_REDIRECTS=true

unset DATABASE_HOST
unset DATABASE_PORT
unset DATABASE_DB

echo "update remote organization hostname"
echo "UPDATE decidim_organizations SET host='3000-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST';" | bundle exec rails dbconsole -p
echo 'Decidim::User.first.update(accepted_tos_version: DateTime.now, admin_terms_accepted_at: DateTime.now, password_updated_at: DateTime.now)' | bundle exec rails c

bin/rails server