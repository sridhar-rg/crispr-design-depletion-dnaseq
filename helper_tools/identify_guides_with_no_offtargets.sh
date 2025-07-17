#! /usr/bin/bash

input_file=$1;
output_file=$2;

grep "NGG/0/0" $input_file | awk -v FS="\t" -v OFS="\t" '{if ($6=="+") print $4;}' | awk -v FS="/" '{print $1;}' | sed -e "s/NGG/AGG/g" > $output_file;