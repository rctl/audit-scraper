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
echo "Use flag -s for utilizing validation of json with hjson"
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
        if [ -z "$(ls -A $REPO)" ];
        then
            echo "Repo '$(basename $USER)/$(basename $REPO)' is empty"
            continue
        fi

        #Extract data from logs in commit
        for COMMIT in "${REPO}/"*
        do
            I2=$((I2+1))
            echo -ne "COMMIT: $I2/$TOTALCOMMITS"\\r
            cd $COMMIT
            TIMESTAMP=$(basename $COMMIT)
            #Process audit.log
            #Format: column1: column2
            if [ -f 'audit.log' ]; then            
                echo "COMMIT,$TIMESTAMP" >> "$DIR/audit.csv"
                awk -F\│ 'NF{if ($2  !~ /Low|High|Moderate|Critical|Package|Dependency of/) {next} gsub(/ /, "", $0); print $2","$3}' audit.log>> "$DIR/audit.csv"
            fi

            #Process package.json 
            #Format: name: version
            #(bundledDependencies are formatted as: name: null)
            if [ -f 'package.json' ] && [ ! -z 'package.json' ]; then
                echo "COMMIT,$TIMESTAMP" >> "$DIR/package.csv"
                if $SAFE ; then
                    hjson -j package.json | jq ' (select(.bundledDependencies != null) | reduce .bundledDependencies[] as $i ({}; .[$i] = null)) + .dependencies + .packageDependencies + .devDependencies + .optionalDependencies + {}' | jq -r 'keys[] as $key | "\($key),\(.[$key])"' >>  "$DIR/package.csv"
                else
                    jq ' (select(.bundledDependencies != null) | reduce .bundledDependencies[] as $i ({}; .[$i] = null)) + .dependencies + .packageDependencies + .devDependencies + .optionalDependencies + {}' package.json | jq -r 'keys[] as $key | "\($key),\(.[$key])"' >>  "$DIR/package.csv"
                fi
            fi

            #Procss package.jq
            #Format: name: version
            if [ -f 'package-lock.json' ] && [ ! -z 'package-lock.json' ]; then
                echo "COMMIT,$TIMESTAMP" >> "$DIR/package-lock.csv"
                if $SAFE ; then
                    hjson -j package-lock.json | jq '.dependencies + {}' | jq -r 'keys[] as $key | "\($key),\(.[$key].version)"' >>  "$DIR/package-lock.csv"
                else
                    jq '.dependencies + {}' package-lock.json | jq -r 'keys[] as $key | "\($key),\(.[$key].version)"' >>  "$DIR/package-lock.csv"
                fi
            fi
        done
    echo ""
    done
done
