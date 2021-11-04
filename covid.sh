#!/bin/bash
WORKDIR="/Users/jeichert/tmp"

echo "Country;24h;7days" > $WORKDIR/out

# Processing Alaska from NYTimes
printf "\n****************\nProcessig Alaska\n****************\n\n"
curl -s "https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv" | grep Alaska | tail -n 8 > $WORKDIR/data.csv
sort -r $WORKDIR/data.csv | awk -F "\"*,\"*" '{print $4}' > $WORKDIR/calc.tmp
NEW=`head -n 1 $WORKDIR/calc.tmp`
OLD24H=`head -n 2 $WORKDIR/calc.tmp | tail +2`
OLD7D=`tail -n 1 $WORKDIR/calc.tmp`
DIFF7D=`expr $NEW - $OLD7D`
echo "Alaska;`expr $NEW - $OLD24H`;`expr $DIFF7D / 7`" >> $WORKDIR/out
rm $WORKDIR/calc.tmp

printf "\n****************\nProcessig WHO\n****************\n\n"

# Fetch WHO Data
curl -s "https://covid19.who.int/WHO-COVID-19-global-table-data.csv" > $WORKDIR/data.csv

# replace Commas by Semicolons
sed "s/\,/\;/g" $WORKDIR/data.csv > $WORKDIR/data_tmp.csv
rm $WORKDIR/data.csv

# Extract data we are interested in
egrep -e 'United States of A' \
      -e 'Germany'            \
      -e 'France'             \
      -e 'The United Kingdom' \
      -e 'Italy'              \
      -e 'Spain'              \
      $WORKDIR/data_tmp.csv | awk -F "\"*;\"*" '{print $1 ";" $7 ";" $5/7}' >> $WORKDIR/out

sed "s/\./\,/g" $WORKDIR/out > $WORKDIR/out.csv

# Cleanup
rm $WORKDIR/out
rm $WORKDIR/data_tmp.csv

#Display the result
cat $WORKDIR/out.csv

# create a save file to verify if there was an update
if [ -f $WORKDIR/out.csv.previous ]; then
    DIFF=`diff $WORKDIR/out.csv $WORKDIR/out.csv.previous`
    if [[ $DIFF != "" ]]; then
        printf "\n** UPDATED **\n\n"
    fi

    rm $WORKDIR/out.csv.previous 2> /dev/null
fi
cp $WORKDIR/out.csv $WORKDIR/out.csv.previous
