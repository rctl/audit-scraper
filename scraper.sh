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
  FILES=("package-lock.json" "package.json")
  for FILE in "${FILES[@]}"; do
    if [ ! -f "$FILE" ]; then
      echo "Skipped missing $FILE"
      continue
    fi
    echo "Investigating $FILE..."
    VERSIONS=$(git log --pretty=format:"%H" $FILE)
    for VERSION in $VERSIONS; do
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
      cp $FILE $DATA_DIR/$NAME/$COMMIT_TIME 2>/dev/null || :
    done
  done

  # remove temp dir
  rm -rf $TMP_DIR/$NAME
done
