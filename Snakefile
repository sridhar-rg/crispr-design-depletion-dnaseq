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
    #           and to generate the number of target sites for each guide
    #           in the genome. This estimate is an important metric that 
    #           will define whether or not a guide will be prioritized over
    #           another. For example, a guide with 10 target sites will be
    #           more favored over another with just 1 target site for this
    #           application. 
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
    #           and other downstream steps. 
    #
    #           An obvious alternate method is to run CRISflash by providing it a "candidate"
    #           sequence (unprotected genome) and a pseudogenome (protected genome). However, 
    #           for larger genomes (eg. hg38, T2T), this becomes a memory and time intensive
    #           task. This is just a trick to speed up the process by a day or two.
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
    #           Note: There may be guides that will (also) target protected regions. Do
    #           not worry about these guides because they will be removed in the offtarget
    #           filter step
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
    # We use multiple parameters to remove gRNAs. I have included only 2-3.
    # These gRNAs will be synthesized as oligos in a in vitro transcription reaction.
    # This reaction is sensitive to many elements of the gRNA target sequence 
    # I cannot provide all material that Jumpcode employs because this is a secret sauce
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
    # The output is a BED file with the gRNA target sequence in the 4-th column. 
    # This step merely takes the DNA sequence of the guides and converts it to a fasta file.
    # Why fasta? This fasta can be provided to CRISflash and we can trick it to think these 
    # are the guides that we want. Essentially, we tell CRISflash "here is the guide sequence
    # on which you need to find the guide sequence. and give me the information on their hits
    # on the protected genome - in the next step (off-target filter)"
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
    # We are only interested to see if guides target the protected regions. 
    # So we take the genome and mask everything but the protected genome. 
    # This way CRISflash will only need to work with hits of the filtered guides
    # on the protected genome (<10%) and hence, lower memory and faster times.
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
    # Crucial step: Essentially, we tell CRISflash "here is the guide sequence
    # on which you need to find the guide sequence. and give me the information on their hits
    # on the protected genome - in the next step (off-target filter)". There are a few issues
    # that can happen here. A gRNA that starts with a CC- could be an issue. How? 

    # Example gRNA: CCACGTACGTACGTACGTACAGG
    # CRISFlash would identify a gRNA site on this gRNA from 5'- to 3'-
    # Additionally there is also another gRNA on this gRNA that runs from 3'- to 5'-
    # So we also check the strand of the identified gRNA and remove them from being considered
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
    # CRISflash outputs the off-target filtered guides along with the number of hits
    # Since the numbers reported will be exclusively on the protected regions (remember, 
    # we masked everything but the protected genomes), any guide no hits is fit enough to be selected

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
    # We use all off-target filtered guides, put them in a text file and use a java script
    # that runs these guides against the list of all guides in the genome.

    # Additionally, the java script also re-calculates the number of on-target hits for each
    # guide in the genome. This is important because we want to prioritize guides with many
    # on-target hits (handled in the distance filtering step)
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
    # Need a BED file that is a complement of the protected regions - basically all sections of the 
    # genome that will be depleted
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
    # Distance filtering:
    # We have used multiple methods. I cannot reveal the exact method because that's part of
    # jumpcode's recipe. What I can say is that we want to make sure a few things happen:

    # 1. When guides target too close to each other, they run into what we observed as a crowding effect?
    #    Basically, we don't want two cable cars running in opposite directions or two close with 
    #    variable speeds. So we make sure the cables are as long as we can allow them to be. 
    #
    #    We do not want two Cas enzymes on the same cDNA molecule binding and cleaving it. It is wasteful
    #    and in terms of time / kinetics of the reaction, it is highly critical that the Cas enzyme finds
    #    as many targets as it quickly can. 

    # 2. When they are too far from each other, we don't deplete enough
    #    This is because in short-read sequencing libraries, typical fragment sizes are 300-500 nt. You don't
    #    want the guide targets to be > fragment lengths / 2. So that sort of presents itself as a guardrail. 
    #    Now, there are workarounds we have found for this (shhh)
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
