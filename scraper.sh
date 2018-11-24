#!/bin/bash

set -e

# absolute dir to temp files
TMP_DIR="$(pwd)/tmp"
if [ ! -d "$TMP_DIR" ]; then
  mkdir -p $TMP_DIR
fi

# absolute dir to data files
DATA_DIR="$(pwd)/data/sources"
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
  # setup tmp
  echo "Creating tempdir for $NAME..."
  mkdir -p $TMP_DIR/$NAME

  # clone
  echo "Cloning $NAME..."
  URL="https://github.com/$NAME.git"
  cd $TMP_DIR/$NAME
  git clone $URL .

  # setup data dir
  if [ ! -d "$DATA_DIR/$NAME" ]; then
      mkdir -p $DATA_DIR/$NAME
  fi

  # investigate files
  if [ ! -f "package.json" ]; then
    echo "Skipped missing package.json"
    continue
  fi
  echo "Investigating package.json..."
  VERSIONS=$(git log --pretty=format:"%H" package.json)
  for VERSION in $VERSIONS; do
    cd $TMP_DIR/$NAME
    echo "Checking out $VERSION"
    git checkout $VERSION
    # from master branch get package-lock.json and npm audit
    COMMIT_TIME=$(git show -s --format=%ct)
    if [ -d "$DATA_DIR/$NAME/$COMMIT_TIME" ]; then
        echo "Skipped commit for $NAME directory already exists"
        continue
      else
        mkdir -p $DATA_DIR/$NAME/$COMMIT_TIME
    fi
    # copy relevant files
    cp package.json $DATA_DIR/$NAME/$COMMIT_TIME 2>/dev/null || :
    cp package-lock.json $DATA_DIR/$NAME/$COMMIT_TIME 2>/dev/null || :

    # audit the version and save a log
    cd $DATA_DIR/$NAME/$COMMIT_TIME
    if [ ! -f "package-lock.json" ]; then
      npm install --package-lock-only
    fi
    npm audit 2>&1 > audit.log || :
  done

  # remove temp dir
  rm -rf $TMP_DIR/$NAME
done
