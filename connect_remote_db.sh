#!/bin/bash

echo "Set env vars"
export DATABASE_HOST=$DEV_DB_HOST
export DATABASE_PORT=$DEV_DB_PORT
export DATABASE_USER=$DEV_DB_USER
export DATABASE_PASSWORD=$DEV_DB_PASSWORD
export DATABASE_DB=$DEV_DB_NAME
export DATABASE_URL=postgresql://$DEV_DB_USER:$DEV_DB_PASSWORD@$DEV_DB_HOST:$DEV_DB_PORT/$DEV_DB_NAME
unset PGHOSTADDR

echo "update remote organization hostname"
echo "UPDATE decidim_organizations SET host='3000-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST';" | bin/rails dbconsole -p

bin/rails s
