#! /usr/bin/bash

# Purpose:
# Obtain the command-line arguments:
#   1. Reference fasta file for the genome
#   2. Path to crisflash executable
#   3. BED file containing regions of the genome that should NOT be depleted
#   4. Folder where the design outputs should be stored (optional)

set -eo pipefail;

usage() {
  cat >&2 << EOF
  Usage: bash $0 [options]

  Options:

  -r <reference fasta>          Path to the reference fasta file of the host genome
  -c <crisflash exec>           Path to the crisflash executable software
  -p <protected bed file>       Path to the BED file containing protected regions in the genome
  -d <design output folder>     Path to the output folder (default: reference fasta folder)
  -h <print usage>              Prints the usage options for this script

EOF
}

while getopts "p:r:c:d:h:l:T" OPTION; do
  case $OPTION in
    r) ref_fasta=$OPTARG;;
    p) protected_bed=$OPTARG;;
    c) crisflash=$OPTARG;;
    d) design_folder=$OPTARG;;
    l) log_folder=$OPTARG;;
    T) tmp_folder=$OPTARG;;
    h) usage; exit 1;;
    [?]) usage; (&> echo "Exception: Unknown option specified $OPTARG"); exit 1;;
  esac
done

missing_args=();

if [[ -z "$ref_fasta" ]]; then missing_args+=("-r not specified by the user"); fi
if [[ -z "$crisflash" ]]; then missing_args+=("-c not specified by the user"); fi
if [[ -z "$protected_bed" ]]; then missing_args+=("-p not specified by the user"); fi
if [[ -z "$design_folder" ]]; then design_folder="design"; fi
if [[ -z "$log_folder" ]]; then log_folder="logs"; fi
if [[ -z "$tmp_folder" ]]; then tmp_folder="tmp"; fi

if [ ${#missing_args[@]} -ne 0 ]; then
  usage; 
  echo "Missing arguments:" >&2;
  for missing_arg in "${missing_args[@]}"; do 
    echo -e "\t$missing_arg" >&2;
  done
  exit 1;
fi

echo -e "ARGUMENTS: OK";

# Create necessary files and folders
ref_folder=$(dirname $ref_fasta | xargs realpath);
mkdir -p $ref_folder/$design_folder;
mkdir -p $ref_folder/$log_folder;

snakefile="Snakefile"; # modify this to point to the snakefile
mkdir -p $ref_folder/snk_tmp;

snakemake \
  --shadow-prefix $ref_folder/snk_tmp \
#  --configfile config/config.yml \
  --config ref_fasta=$ref_fasta crisflash=$crisflash protected_bed=$protected_bed design_folder=$design_folder log_folder=$log_folder tmp_folder=$tmp_folder \
  --restart-times 1 \
  --keep-going \
  --printshellcmds \
  --snakefile $snakefile
;

# Other things that can be automated

# 1. Preparing the reference genome for crisflash design step 
#    - fasta headers need to be fixed to have one-word headers e.g. >NM_000001.11
#    - fasta sequences should not have IUPAC ambiguous DNA 
#    - fasta sequences should not have any soft-masked DNA (convert to uppercase)

# 2. Making the reference genome file (2-col file with chr headers and length)
#    - samtools faidx [ref_fasta]
#    - awk to get specific columns from .faidx file

#    Include a shell script file that does this as an example with the documentation


