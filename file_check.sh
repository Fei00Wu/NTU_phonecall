#! /bin/bash

printf "\t Check data directory: %s.\n" "$1"
mkdir -p $1/.backup

for file in $1/*; do 
    if [ -f $file ]; then
        echo "$file exists. Moved old file to .backup"
        mv $file $1/.backup/$(basename $file)
    fi
done



