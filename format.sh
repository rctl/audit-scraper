#!/bin/bash
SAFE=false
while getopts 's' flag; do
  case "${flag}" in
    s) SAFE=true ;;
  esac
done
SOURCES="$(pwd)/sources"
RESULTS="$(pwd)/csv"
rm -rf $RESULTS
mkdir -p $RESULTS
I=0
TOTAL=$(($(ls -ld $SOURCES/* | wc -l)-1))
$SAFE || echo "Use flag -s for utilizing validation of json with hjson"
for USER in "${SOURCES}/"*
do
    I=$((I+1))
    echo "USER: $(basename $USER) [$I/$TOTAL]"

    for REPO in "${USER}/"*
    do
        DIR="$RESULTS/$(basename $USER)/$(basename $REPO)/"
        mkdir -p $DIR
        I2=0
        TOTALCOMMITS=$(($(ls -l $REPO | wc -l)-1))
        if [ -z "$(ls -A $REPO)" ]; then
            echo "Repo '$(basename $USER)/$(basename $REPO)' is empty"
            continue
        fi

        # Prepare CSV headers
        echo "COMMIT_TIME,DEPENDENCY,VERSION" > "$DIR/package-lock.csv"
        echo "COMMIT_TIME,DEPENDENCY,VERSION" > "$DIR/package.csv"
        printf "Timestamp,Severity,Type,Package,Dependencyof" > "$DIR/audit.csv"

        # Extract data from logs in commit
        for COMMIT in "${REPO}/"*
        do
            I2=$((I2+1))
            echo -ne "COMMIT: $I2/$TOTALCOMMITS"\\r
            cd $COMMIT
            TIMESTAMP=$(basename $COMMIT)

            # Process audit.log
            # Format: Timestamp,Severity,Type,Package,Dependencyof
            if [ -f 'audit.log' ]; then
                awk -v commit="$TIMESTAMP" -F\│ 'NF{if ($1 ~ /^ *┌.*┬/) {printf "\n%s", commit} if ($2  !~ /Low|High|Moderate|Critical|Package|Dependency of/) {next} gsub(/ /, "", $0); if($2 ~ /Low|High|Moderate|Critical/){$3=$2","$3} printf ",%s", $3 }' audit.log \
                >> "$DIR/audit.csv"
            fi

            # Process package.json 
            # Format: name: version
            # (bundledDependencies are formatted as: name: null)
            if [ -f 'package.json' ] && [ ! -z 'package.json' ]; then
                ($SAFE && hjson -j package.json || cat package.json)  | \
                    jq ' (select(.bundledDependencies != null) | reduce .bundledDependencies[] as $i ({}; .[$i] = null)) + .dependencies + .packageDependencies + .devDependencies + .optionalDependencies + {}' | \
                    jq -r --arg TIMESTAMP "$TIMESTAMP" 'keys[] as $key | "\($TIMESTAMP),\($key),\(.[$key])"' \
                    >>  "$DIR/package.csv"
            fi

            # Process package-lock.json
            # Format: name: version
            if [ -f 'package-lock.json' ] && [ ! -z 'package-lock.json' ]; then
                ($SAFE && hjson -j package-lock.json || cat package-lock.json) | \
                    jq '.dependencies + {}' | \
                    jq -r --arg TIMESTAMP "$TIMESTAMP" 'keys[] as $key | "\($TIMESTAMP),\($key),\(.[$key].version)"' \
                    >>  "$DIR/package-lock.csv"
            fi
        done
    echo
    done
done
