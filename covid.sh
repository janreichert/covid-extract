#!/bin/bash
WORKDIR="/Users/jeichert/tmp"

ECDC="https://opendata.ecdc.europa.eu/covid19/nationalcasedeath_eueea_daily_ei/csv/data.csv"
NYTIMES="https://raw.githubusercontent.com/nytimes/covid-19-data/master/us-states.csv"
WHO="https://covid19.who.int/WHO-COVID-19-global-table-data.csv"
POPULATION="https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/UID_ISO_FIPS_LookUp_Table.csv"

SKIP="N"
LOOP="N"
PREVIOUS="N"
UPDATED="N"

usage() {
    echo $(basename "$0") [-s] [-l n]
    echo "-s skip dataset fetch (for testing purposes)"
    echo "-l loop (experimental, sleep for n minutes, default 120=2hours)"
    echo
    echo "current datasets:"
    echo "   NYTIMES: $NYTIMES"
    echo "   ECDC: $ECDC"
    echo "   WHO: $WHO"
    exit 1
}

while (($#)); do 
    case $1 in
        -s)
            SKIP="Y"
        ;;
        -l)
            LOOP="Y"
            if [[ $2 = "" ]]; then
                SLEEP=120
            else
                (( SLEEP = $2 * 60 ))
                shift
            fi
            
        ;;
        *)
            usage;;
    esac
    shift
done


datasets() {
    if [[ $SKIP = "N" ]]; then
        # Processing NYTimes
        printf "Fetching NYTIMES Dataset\n"
        curl -s $NYTIMES > $WORKDIR/nytimes.csv 
    
        # Processing ECDC
        printf "Fetching ECDC Dataset\n"
        curl -s $ECDC > $WORKDIR/ecdc.csv

        # Processing WHO
        printf "Fetching WHO Dataset\n"
        curl -s $WHO > $WORKDIR/who.csv

        # Processing POPULATION
        # Hardly parseable as some fields contain , 
        # I need to rewrite this in python or go
        # printf "Fetching Population Count Dataset\n"
        # curl -s $POPULATION > $WORKDIR/population.csv
    fi
}

if [ -f $WORKDIR/out.csv.previous ]; then
    PREVIOUS="Y"
fi

while true; do
    clear
    printf "\033[1;31mUpdate `date` \033[0m\n"
    if [ $LOOP = "Y" ]; then
        echo "Loop with a $SLEEP sleep"
    fi
    echo "Country;24h;7days" > $WORKDIR/out.csv

    datasets

    for STATE in "Alaska" "Washington"; do
        printf "\033[1;32mProcessing \033[0m"
        grep $STATE $WORKDIR/nytimes.csv | tail -n 8 | sort -r | awk -F "\"*,\"*" '{print $4}' > $WORKDIR/$STATE.csv
        NEW=`head -n 1 $WORKDIR/$STATE.csv`
        OLD24H=`head -n 2 $WORKDIR/$STATE.csv | tail +2`
        OLD7D=`tail -n 1 $WORKDIR/$STATE.csv`
        DIFF7D=`expr $NEW - $OLD7D`
        OUTPUT="$STATE;`expr $NEW - $OLD24H`;`expr $DIFF7D / 7`"
        echo $OUTPUT

        if [[ $PREVIOUS = "Y" ]]; then
            if [[ $OUTPUT != `grep $STATE $WORKDIR/out.csv.previous` ]]; then
                echo "   UPDATED"
            fi 
        fi
        echo $OUTPUT >> $WORKDIR/out.csv
        #rm $WORKDIR/$STATE.csv
    done

    for COUNTRY in "Austria" "France" "Germany" "Italy" "Spain"; do
        printf "\033[1;32mProcessing \033[0m"
        grep $COUNTRY $WORKDIR/ecdc.csv | head -n 7 | awk -F "\"*,\"*" '{print $5}' > $WORKDIR/$COUNTRY.csv
        NEW=`head -n 1 $WORKDIR/$COUNTRY.csv`
        TOTAL7D=0
        for CASES in `cat $WORKDIR/$COUNTRY.csv`; do
            TOTAL7D=`expr $TOTAL7D + $CASES`
        done
        OUTPUT="$COUNTRY;$NEW;`expr $TOTAL7D / 7`"
        echo $OUTPUT

        if [[ $PREVIOUS = "Y" ]]; then
            if [[ $OUTPUT != `grep $COUNTRY $WORKDIR/out.csv.previous` ]]; then
                echo -e "\033[1;31m   UPDATED\033[0m"
            fi 
        fi
        echo $OUTPUT >> $WORKDIR/out.csv
        #rm $WORKDIR/$COUNTRY.csv
    done

    for COUNTRY in "The United Kingdom" "United States of America"; do
        printf "\033[1;32mProcessing \033[0m"
        OUTPUT=`grep "$COUNTRY" $WORKDIR/who.csv | sed "s/\,/\;/g"    \
            | awk -F "\"*;\"*" '{print $1 ";" $7 ";" $5/7}' \
            | sed "s/\([^\.]*\).*/\1/"`
        echo $OUTPUT

        if [[ $PREVIOUS = "Y" ]]; then
            if [[ $OUTPUT != `grep "$COUNTRY" $WORKDIR/out.csv.previous` ]]; then
                echo -e "\033[1;31m   UPDATED\033[0m"
            fi 
        fi
        echo $OUTPUT >> $WORKDIR/out.csv        
    done

    # create a save file to verify if there was an update
    if [[ $PREVIOUS = "Y" ]]; then
        DIFF=`diff $WORKDIR/out.csv $WORKDIR/out.csv.previous`
        if [[ $DIFF != "" ]]; then
            UPDATED="Y"
        fi
    else
        cp $WORKDIR/out.csv $WORKDIR/out.csv.previous
    fi
    
    if [[ $LOOP = "N" || $UPDATED = "Y" ]]; then
        break
    fi
    sleep $SLEEP
done

printf "\n\033[1;31mOutput\033[0m"
if [[ $UPDATED = "Y" ]]; then
    rm $WORKDIR/out.csv.previous 2> /dev/null
    printf "\033[1;31m *** UPDATED ***\033[0m"
    cp $WORKDIR/out.csv $WORKDIR/out.csv.previous
fi

printf "\n\n"

#Display the result
cat $WORKDIR/out.csv
printf "\n"
