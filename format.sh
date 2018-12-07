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
        echo "COMMIT,TOTAL,LOW,MODERATE,HIGH,CRITICAL" > "$DIR/audit_sum.csv"

        # Extract data from logs in commit
        for COMMIT in "${REPO}/"*
        do
            I2=$((I2+1))
            echo -ne "COMMIT: $I2/$TOTALCOMMITS"\\r
            cd $COMMIT
            TIMESTAMP=$(basename $COMMIT)

            if [ -f 'audit.log' ]; then
                SUM=$(grep "found" audit.log)
                LOW=$(echo $SUM | grep -o -E "\d+ low" | cut -d' ' -f 1 | grep -E "\d" || echo "0")
                MODERATE=$(echo $SUM | grep -o -E "\d+ moderate" | cut -d' ' -f 1 | grep -E "\d" || echo "0")
                HIGH=$(echo $SUM | grep -o -E "\d+ high" | cut -d' ' -f 1 | grep -E "\d" || echo "0")
                CRITICAL=$(echo $SUM | grep -o -E "\d+ critical" | cut -d' ' -f 1 | grep -E "\d" || echo "0")
                TOTAL=$(echo $SUM | grep -o -E "\d+ scanned" | cut -d' ' -f 1 | grep -E "\d" || echo "0")
                echo "$TIMESTAMP,$TOTAL,$LOW,$MODERATE,$HIGH,$CRITICAL" >> "$DIR/audit_sum.csv"
            fi

            # Process audit.log
            # Format: Timestamp,Severity,Type,Package,Dependencyof
            if [ -f 'audit.log' ]; then
                awk -v commit="$TIMESTAMP" -F\│ 'NF{if ($1 ~ /^ *┌.*┬/) {printf "\n%s", commit} if ($2  !~ /Low|High|Moderate|Critical|Package|Dependency of/) {next} gsub(/ /, "", $0); if($2 ~ /Low|High|Moderate|Critical/){$3=$2","$3} printf ",%s", $3 }' audit.log \
                >> "$DIR/audit.csv"
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
