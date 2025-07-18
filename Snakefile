#!/bin/python

import os

from pathlib import Path
from util.snakemake_util import SNAKEFILE_DIR

configfile: "config/config.yml" # Alternatively, pass or override configurations manually

ref_fasta=config['ref_fasta']               # path to reference genome fasta
crisflash=config['crisflash']               # path to crisflash executable
pam=config['pam']                           # PAM site for gRNA target (e.g. NGG, NAG)
protected_bed=config['protected_bed']       # path to bed file containing protected regions in the genome
design_folder=config['design_folder']       # path to design output folder
log_folder=config['log_folder']             # path to log folder
tmp_folder=config['tmp_folder']             # path to tmp folder
helper_tools=config['helper_tools']         # path to folder containing helper tools

rule all:
    input:
        os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".distance_filtered.bed"))
        )

rule master_guide_list:
    # Step 01:  Identify all possible target sites in the genome
    #           This includes target sites on the protected regions
    #           This is performed to collate the guides at a later step
    input:
        fasta = ref_fasta
    output:
        bed = os.path.join(
            design_folder,
            os.path.basename(ref_fasta.replace(".fa", ".crisflash.ngg.bed"))
        )
    params:
        design_tool = crisflash,
        pam = pam
    log:
        os.path.join(log_folder, "crisflash_genome.log")
    shell:
        """
        {params.design_tool} -g {input.fasta} -p {params.pam} -o {output.bed} > {log} 2>&1
        """

rule make_protected_regions_masked_fasta:
    # Step 02:  Make a reference fasta with protected regions masked.
    #           This is necessary in larger genomes to preserve the coordinates of the
    #           guide target sites. These coordinates are necessary for distance filtering
    #           and other downstream steps
    input:
        bed = protected_bed,
        fasta = ref_fasta,
        genome = ref_fasta.replace(".fa", ".genome")
    output:
        masked = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".protected_regions.masked.fa"))
        )
    log:
        os.path.join(log_folder, "mask_protected_regions.log")
    shell:
        """
        bedtools merge -i {input.bed} | \
        bedtools sort -i - -g {input.genome} | \
        bedtools maskfasta -fi {input.fasta} -bed - -fo {output.masked} > {log} 2>&1
        """

rule get_initial_guide_list:
    # Step 03:  Identify all possible target sites in regions that need to be depleted
    #           Use a fasta file that has the protected regions masked
    #           Note: There may be guides that will (also) target protected regions
    #                 which will be handled at a later step
    input:
        fasta = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".protected_regions.masked.fa"))
        )
    output:
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".initial_depletion_targets.bed"))
        )
    params:
        design_tool = crisflash,
        pam = pam
    log:
        os.path.join(log_folder, "crisflash_genome.log")
    shell:
        """
        {params.design_tool} -g {input.fasta} -p {params.pam} -o {output.bed} &> {log}
        """

rule filter_sequence_complexity:
    input: 
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".initial_depletion_targets.bed"))
        )
    params:
        jvm_options = '-Xmx50g',
        gc_high = 0.65,
        polyN_max = 5,
        dint_max = 4,
        tool = os.path.join(helper_tools, "CrisFlashUtilsFilterGenomeGuidesBySequenceComplexity.jar")
    output:
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".sequence_complexity_filtered.bed"))
        )
    log:
        os.path.join(log_folder, "sequence_complexity_filter.log")
    shell:
        """
        java {params.jvm_options} -jar {params.tool} {input.bed} {output.bed} \
            {params.gc_high} {params.polyN_max} {params.dint_max} &> {log}
        """

# Important Note:

# In scenarios, when there are millions of CRISPR-gRNAs to handle at the end of this step, 
# splitting the BED file into smaller units can save a considerable amount of time and memory.
# The split workflow is not shown in this pipeline...
# You can either use bash or python to split the BED files into < 1M intervals, convert gRNAs 
# to fasta (you might want to add AGG as PAM sites to the 20-mers - refer helper_tools), and 
# perform off-target filtering individually across all these files. 

rule convert_guide_to_fasta:
    input: 
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".sequence_complexity_filtered.bed"))
        )
    output:
        fasta = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".sequence_complexity_filtered.fa"))
        )
    params:
        tool = os.path.join(helper_tools, "convert_crisflash_genome_guides_to_fasta.sh")
    log:
        os.path.join(log_folder, "sequence_filtered_bed_to_fasta.log")
    shell:
         """
        bash {params.tool} {input.bed} {output.fasta} > {log} 2>&1
        """

rule make_depletion_mask_fasta:
    input:
        bed = protected_bed,
        fasta = ref_fasta,
        genome = ref_fasta.replace(".fa", ".genome")
    output:
        masked = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".depleted_regions.masked.fa"))
        )
    log:
        os.path.join(log_folder, "mask_protected_regions.log")
    shell:
        """
        bedtools merge -i {input.bed} | \
        bedtools sort -i - -g {input.genome} | \
        bedtools complement -i - -g {input.genome} | \
        bedtools maskfasta -fi {input.fasta} -bed - -fo {output.masked} > {log} 2>&1
        """

rule filter_offtargets:
    input: 
        offtarget_fasta = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".depleted_regions.masked.fa"))
        ),
        candidate_guide_fasta = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".sequence_complexity_filtered.fa"))
        )
    params:
        design_tool = crisflash,
        pam = pam,
        mismatch_max = 3,
        threads = 10    
    output:
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".off_target.bed"))
        )
    log:
        os.path.join(log_folder, "offtarget_filter.log")
    shell:
        """
        {params.design_tool} -g {input.offtarget_fasta} -s {input.candidate_guide_fasta} \
            -p {params.pam} -m {params.mismatch_max} -t {params.threads} -o {output.bed} &> {log}
        """

rule get_offtarget_filtered_guides:
    input:
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".off_target.bed"))
        )
    params:
        tool = os.path.join(helper_tools, "identify_guides_with_no_offtargets.sh")
    output:
        guides = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".off_target_filtered.txt"))
        )
    log:
        os.path.join(log_folder, "offtarget_filtered_guide_selection.log")
    shell: 
        """
        bash {params.tool} {input.bed} {output.guides} > {log} 2>&1
        """

rule collate_offtarget_filtered_guides:
    input:
        guides = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".off_target_filtered.txt"))
        ),
        genome_guides = os.path.join(
            design_folder,
            os.path.basename(ref_fasta.replace(".fa", ".crisflash.ngg.bed"))
        )
    output:
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".off_target_filtered.bed"))
        )
    params:
        jvm_options = '-Xmx50g',
        tool = os.path.join(helper_tools, "CrisFlashUtilsSelectGenomeGuidesByTargetSequence.jar"),
        pam = pam,
        length = 20
    log:
        os.path.join(log_folder, "collate_offtarget_filtered_guides.log")
    shell:
        """
        java {params.jvm_options} -jar {params.tool} {input.guides} {input.genome_guides} \
        {output.bed} {params.pam} {params.length} &> {log}
        """
rule make_depletion_interval_bed:
    input:
        bed = protected_bed,
        fasta = ref_fasta,
        genome = ref_fasta.replace(".fa", ".genome")
    output:
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".depletion_regions.bed"))
        )
    shell:
        """
        bedtools merge -i {input.bed} | \
        bedtools sort -i - -g {input.genome} | \
        bedtools complement -i - -g {input.genome} > {output.bed}
        """

rule distance_filter_guides:
    input:
        guide_bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".off_target_filtered.bed"))
        ),
        depleted_region_bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".depletion_regions.bed"))
        ) 
    output:
        bed = os.path.join(
            design_folder, 
            os.path.basename(ref_fasta.replace(".fa", ".distance_filtered.bed"))
        )
    params:
        jvm_options = '-Xmx50g',
        tool = os.path.join(helper_tools, "CrisFlashUtilsFilterGenomeGuidesByDistance_test.jar"),
        distance = 200,
        max_guide_per_interval = 1
    log:
        os.path.join(log_folder, "distancce_filter.log")
    shell:
        """
        java {params.jvm_options} -jar {params.tool} {input.depleted_region_bed} {input.guide_bed} \
        {output.bed} {params.distance} {params.max_guide_per_interval} > {log}
        """

# Helper tools:

# 1. CrisFlashUtilsFilterGenomeGuidesBySequenceComplexity.jar
# 2. convert_crisflash_genome_guides_to_fasta.sh
# 3. identify_guides_with_no_offtargets.sh
# 4. CrisFlashUtilsFilterGenomeGuidesByDistance_test.jar
# 5. CrisFlashUtilsSelectGenomeGuidesByTargetSequence.jar