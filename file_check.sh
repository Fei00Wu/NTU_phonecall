#! /bin/bash
# Remove exist files in data directory
# Copyright     2019    Fei Wu
#
# Usage:
# ./file_chack.sh <path_to_data_dir>
# E.g.:
# ./file_check.sh data

printf "\t Check data directory: %s.\n" "$1"
mkdir -p $1/.backup

for file in $1/*; do 
    if [ -f $file ]; then
        echo "$file exists. Moved old file to .backup"
        mv $file $1/.backup/$(basename $file)
    fi
done



