#!/bin/bash

set -e
TMP_DIR="tmp/"
if [ -d "$TMP_DIR" ]; then
  rm -rf $TMP_DIR
fi

DATA_DIR="data/"
if [ ! -d "$DATA_DIR" ]; then
  mkdir -p $DATA_DIR
fi

# scrape data if not present on disk
if [ ! -f "$DATA_DIR/data.json" ]; then
  curl "https://api.github.com/search/repositories?q=language:javascript&sort=stars&order=desc&page="{1..5} | jq "[.items[] | {full_name, stargazers_count}]" | jq -s '[.[][]]' > $DATA_DIR/data.json
fi
REPOS=$(cat $DATA_DIR/data.json)

# extract repo names only from data file
NAMES=$(echo $REPOS | jq ".[] | .full_name" | sed "s/\"//g")

# analyze each repo
for NAME in $NAMES; do 
  # fetch the remote repo
  echo "Cloning $NAME..."
  mkdir -p $TMP_DIR
  URL="https://github.com/$NAME.git"
  if [ ! -d "$DATA_DIR/$NAME" ]; then
      mkdir -p $DATA_DIR/$NAME
  fi
  mkdir -p $TMP_DIR
  cd $TMP_DIR
  git clone $URL .

  # from master branch get package-lock.json and npm audit
  COMMIT_TIME=$(git show -s --format=%ct)
  if [ -d "$DATA_DIR/$NAME/$COMMIT_TIME" ]; then
      echo "Skipped commit for $NAME directory already exists"
      continue
    else
      mkdir -p ../$DATA_DIR/$NAME/$COMMIT_TIME
  fi
  cp package-lock.json ../$DATA_DIR/$NAME/$COMMIT_TIME

  cd ..
  rm -rf $TMP_DIR
done
