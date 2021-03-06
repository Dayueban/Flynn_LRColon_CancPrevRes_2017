# Makefile for "Spatial Variation of the Native Human Colonic Microbiota" Flynn, KJ et al 2017

# Set local variables
REFS = data/references
FIGS = submission
PROC = data/process
MOTHUR = data/mothur
CODE = code
METADATA = data/raw/metadata
GZ_FILES = $(wildcard data/raw/*.fastq.gz)

# utility function to print various variables. For example, running the
# following at the command line:
#
#	make print-BAM
#
# will generate:
#	BAM=data/raw_june/V1V3_0001.bam data/raw_june/V1V3_0002.bam ...
print-%:
	@echo '$*=$($*)'


#################################################################################
#																				#
# Part 1: Get the references 													#
#																				#
# We will need several reference files to complete the analyses including the   #
# SILVA reference alignment and RDP reference taxonomy. 
# Part 1 code is from Schloss lab member Marc Sze
#																				#
#################################################################################

# We want the latest greatest reference alignment and the SILVA reference
# alignment is the best reference alignment on the market. This version is from
# v123 and described at http://blog.mothur.org/2015/12/03/SILVA-v123-reference-files/
# We will use the SEED v. 123, which contain 12,083 bacterial sequences. This
# also contains the reference taxonomy. We will limit the databases to only
# include bacterial sequences.

$(REFS)/silva.seed.align :
	wget -N http://mothur.org/w/images/1/15/Silva.seed_v123.tgz
	tar xvzf Silva.seed_v123.tgz silva.seed_v123.align silva.seed_v123.tax
	mothur "#get.lineage(fasta=silva.seed_v123.align, taxonomy=silva.seed_v123.tax, taxon=Bacteria);degap.seqs(fasta=silva.seed_v123.pick.align, processors=8)"
	mv silva.seed_v123.pick.align $(REFS)/silva.seed.align
	rm Silva.seed_v123.tgz silva.seed_v123.*

$(REFS)/silva.v4.align : $(REFS)/silva.seed.align
	mothur "#pcr.seqs(fasta=$(REFS)/silva.seed.align, start=11894, end=25319, keepdots=F, processors=8)"
	mv $(REFS)/silva.seed.pcr.align $(REFS)/silva.v4.align

# Next, we want the RDP reference taxonomy. The current version is v10 and we
# use a "special" pds version of the database files, which are described at
# http://blog.mothur.org/2014/10/28/RDP-v10-reference-files/

$(REFS)/trainset14_032015.% :
	wget -N http://mothur.org/w/images/8/88/Trainset14_032015.pds.tgz
	tar xvzf Trainset14_032015.pds.tgz trainset14_032015.pds/trainset14_032015.pds.*
	mv trainset14_032015.pds/* $(REFS)/
	rmdir trainset14_032015.pds
	rm Trainset14_032015.pds.tgz

##################################################################################
#																				 #
# Part 2: Run data through mothur 												 #
#																				 #
#	Process fastq data through the generation of files that will be used in the  #
# overall analysis.																 #
#																				 #
##################################################################################

#with the fastq.gzs downloaded into data/raw,
#run kws batch file up until cluster.split
run.mothur : $(MOTHUR)/kws_final.files\
$(GZ_FILES)
	bash $(MOTHUR)/kws_final.batch
	
#run cluster.split command to make the .file, then cluster.split 
run_mothur_kws_all.PBS
	#cluster.split(file=kws_final.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.file, processors=1)


#run everything after cluster.split
run_mothur_kws_all-1.PBS
	calls kws_final_shared.batch


#################################################################################
#
#	Part 3:																		#
# Metadata Processing, General Analysis, Building Figures										#
#																				#
#																				#
#################################################################################
	#figure 1, is it just a dependency since it is an image?

	R -e "source('code/build_figure2.R')"
	
	R -e "source('code/build_figure3.R')"
	
	#random forest model building - make rules for the batch files here 
	
leftPBS_optimized.pbs : $(CODE)/left_optimized.R\

rightPBS_optimized.pbs : $(CODE)/right_optimized.R\

stoolPBS_optimized.pbs : $(CODE)/stool_optimized.R\

bowelPBS_optimized.pbs : $(CODE)/bowel_optimized.R\
	
	R -e "source('code/build_figure4.R')"
	
	R -e "source('code/build_figure5.R')"
	
	R -e "source('code/build_figureS1.R')"



#####################################################################################
#																					#
# Part 4: Pull it all together 														#
#																					#
# Render the manuscript 															#
#																					#
#####################################################################################

write.paper : $(FINAL)/manuscript.Rmd\
		$(FIGS)/fig1.jpg $(FIGS)/figure_2.pdf\
		$(FIGS)/figure_3.pdf $(FIGS).figure_4.pdf\
		$(FIGS)/figure_S1.pdf 










