#! /usr/bin/bash

input_file=$1;
output_file=$2;

awk -v FS="\t" -v OFS="\t" '{print ">"$1,$2,$3,$4;}' $input_file | sed -e "s/\t/:/1" | \
    sed -e "s/\t/-/1" | sed -e "s/\t/\n/1" > $output_file;