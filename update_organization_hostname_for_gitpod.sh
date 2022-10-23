#!/bin/bash

echo "UPDATE decidim_organizations SET host='3000-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST';" | bin/rails dbconsole -p
