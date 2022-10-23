#!/bin/bash

export DATABASE_HOST=localhost
export DATABASE_PORT=5432
export DATABASE_USER=gitpod
unset DATABASE_PASSWORD
export DATABASE_DB=postgres
export DATABASE_URL=postgresql://gitpod@localhost
export PGHOSTADDR=127.0.0.1

unset DATABASE_HOST
unset DATABASE_PORT
unset DATABASE_DB

echo "update remote organization hostname"
echo "UPDATE decidim_organizations SET host='3000-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST';" | bundle exec rails dbconsole -p

bin/rails server