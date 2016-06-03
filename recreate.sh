#!/bin/sh

db='manga'
root=`pwd`

# Physical copies

mysql $db < physical/sql/create.sql
mysql $db < physical/sql/insert_entries.sql

# Manga Reference

cd manga

ruby parse_publishers.rb > sql/insert_publishers.sql 2> /dev/null &
publishersPid=$!

ruby parse_authors.rb > sql/insert_authors.sql 2> /dev/null &
authorsPid=$!

ruby parse_series.rb > sql/insert_series.sql 2> /dev/null &
seriesPid=$!

wait $publishersPid $authorsPid $seriesPid

mysql $db < sql/create.sql
mysql $db < sql/insert_series.sql
mysql $db < sql/insert_authors.sql
mysql $db < sql/insert_publishers.sql
mysql $db < sql/index.sql

cd ..

# ISBN lookups

cd isbn

ruby parse_webcat.rb > sql/insert_webcat.sql 2> /dev/null

mysql $db < sql/create.sql
mysql $db < sql/insert_webcat.sql
mysql $db < sql/index.sql

cd ..
