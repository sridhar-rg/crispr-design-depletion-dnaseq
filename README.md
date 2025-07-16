# CRISPR Design for Depletion of Abundant Molecules in DNA Sequencing Applications

Description of bioinformatics pipelines and methods to design CRISPRs for DNA sequencing applications

## The Problem: 

DNA sequencing is a popular method to interrogate the genome. However, for applications that require enhanced sequencing depth at targeted sections of the genome, whole-genome sequencing (WGS) comes with some challenges. Here are some examples:

1. For metagenomics studies, the host DNA often dominates sequencing data and dilutes the microbial content for genome assemblies
2. In argi-genomics applications (e.g. plant genotyping), researchers would like to study the variants in the functional parts of plant genomes. Plant genomes are generally larger and less than 5% of their genome is functional. WES is a viable alternative, but may require the design and synthesis of probes (and the expenses that come with it)
3. The study of gene regulation in animal genomes is another example where 10-20% of the genome requires additional focus

The **biological questions** we seek to answer are: 

*Can CRISPRs be used to remove DNA molecules originating from undesired sections of the genome?*

*Can this, in turn, boost sequencing resolution on target regions of interest?*

In comparison to the design challenges of *in vivo* gene editing, this application requires, perhaps, thousands of CRISPR-gRNAs to deplete a vast majority of nucleic acid molecules. Hence, the **bioinformatics challenge** is to answer:

*How can we assemble a bioinformatics CRISPR design pipeline with all necessary guardrails that provide gRNAs for in vitro depletion of dsDNA or cDNA molecules in a library preparation process?*

Note: 

1. The DASH (https://genomebiology.biomedcentral.com/articles/10.1186/s13059-016-0904-5) methodology introduced by Gu *et* *al* (2016) uses a similar technique to deplete mitochondrial rRNA in HeLa cells. 

2. Jumpcode Genomics owns the intellectual property for commercial use of this method. Please reach out to [Keith Brown](keith@jumpcodegenomics.com) for commercial queries. 

3. I have developed bioinformatics pipelines that design CRISPR-gRNAs for Jumpcode Genomics products using tools that are not used in the code published here. Most of the code used in this repository uses publicly available libraries, tools and genomics software. 

