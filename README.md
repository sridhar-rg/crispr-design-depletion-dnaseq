# CRISPR Design for Depletion of Abundant Molecules in DNA Sequencing Applications

Description of bioinformatics pipelines and methods to design CRISPRs for DNA sequencing applications

## The Problem: 

DNA sequencing is a popular method to interrogate the genome. However, for applications that require enhanced sequencing depth at targeted sections of the genome, whole-genome sequencing (WGS) comes with some challenges. Here are some examples:

1. For metagenomics studies, the host DNA often dominates sequencing data and dilutes the microbial content for genome assemblies
2. In argi-genomics applications (e.g. plant genotyping), researchers would like to study the variants in the functional parts of plant genomes. Plant genomes are generally larger and less than 5% of their genome is functional. WES is a viable alternative, but may require the design and synthesis of probes (and the expenses that come with it)
3. The study of gene regulation in animal genomes is another example where 10-20% of the genome requires additional focus

Furthermore, PCR enzymes that amplify adapter-ligated nucleic acid molecules contribute to a jackpotting effect further increasing abundant DNA. The need here is a method that can selectively remove undesirable molecules *prior* to sequencing. To this end, CRISPR endonucleases offer a simple solution. The CRISPR-Cas enzyme fused with a small guide-RNA (gRNA) molecule whose sequence is complementary to the target DNA can offer (arguably) a high degree of specificity in cleaving them. If these gRNAs can be carefully designed to cut uniquely the undesirable DNA after adapter ligation, one can take advantage of clean-up and PCR steps that simply leave behind these molecules. The result would be a final sequencing library highly enriched with only the target molecules of interest for the application. 

In order to develop such a method, the **biological questions** we seek to answer are: 

1. *Can CRISPRs be used to remove DNA molecules originating from undesired sections of the genome?*

2. *Can this, in turn, boost sequencing resolution on target regions of interest?*

Compared to the design challenges in *in vivo* gene editing, this application requires thousands of CRISPR-gRNAs to deplete a vast majority of nucleic acid molecules in sequencing libraries. Hence, the **bioinformatics challenge** is to answer:

*How can we assemble a bioinformatics CRISPR design pipeline with all necessary guardrails that provide gRNAs for in vitro depletion of dsDNA or cDNA molecules in a library preparation process?*

Important Notes: 

1. The DASH (https://genomebiology.biomedcentral.com/articles/10.1186/s13059-016-0904-5) methodology introduced by Gu *et* *al* (2016) uses a similar technique to deplete mitochondrial rRNA in HeLa cells. 

2. Several other studies have been published that uses the power of CRISPRs to deplete abundant RNA and DNA molecules from sequencing libraries. Here are a couple of papers that I have worked on: [single cell RNA application](https://pubmed.ncbi.nlm.nih.gov/40389438/) and [infectious disease detection](https://www.cell.com/cell-reports-methods/pdf/S2667-2375(23)00082-6.pdf)

3. Jumpcode Genomics owns the intellectual property for commercial use of this method. Please reach out to [Keith Brown](keith@jumpcodegenomics.com) for commercial queries. 

4. I have developed bioinformatics pipelines that design CRISPR-gRNAs for Jumpcode Genomics products using tools that are not used in the code published here. Most of the code used in this repository uses publicly available libraries, tools and genomics software. 

