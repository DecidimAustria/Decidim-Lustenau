#!/bin/bash

echo "UPDATE decidim_organizations SET host='localhost';" | bin/rails dbconsole -p
