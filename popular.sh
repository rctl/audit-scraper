#!/bin/bash
RESULTS="$(pwd)/csv"
SOURCES="$(pwd)/csv"
TMP="$(pwd)/tmp"
[ -d $TMP ] || mkdir $TMP
rm $RESULTS/alldependencies.csv

I=0
TOTAL=$(find csv -name '*lock.csv' | wc -l)
find $SOURCES -name '*lock.csv' -print0 | while IFS= read -r -d $'\0' file; do
    I=$((I+1))
    printf "\rUser: %s/%s"$I$TOTAL
    REPO="$(basename "$(dirname "$file")")"
    awk -v repo=$REPO -F\, 'NR<=1 { next } NF{printf "%s,%s,%s\n",repo,$2,$3}' $file >> $TMP/deps.csv
done

#Remove duplicat dep in same repo and sort in decreasing order
printf "\nCreating dependency list\n"
echo "COUNT,PACKAGE" > $RESULTS/alldependencies.csv
sort -u -t, -k1,2 $TMP/deps.csv | sort -t, -k2,2 | awk -F\, 'NF{print $2}'| uniq -c | sort -nr | sed "s/^[ \t]*//" | sed 's/\ /,/g'>> $RESULTS/alldependencies.csv
rm -rf $TMP