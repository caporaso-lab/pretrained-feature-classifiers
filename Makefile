.PHONY: gg silva all clean

gg:
	CLASSIFIER_NAME=gg-13-8-99 \
	MEMORY_515_806=16000 \
	MEMORY_FULL=32000 \
	SOURCE_SEQS=inputs/gg/99_otus.fasta \
	SOURCE_TAX=inputs/gg/99_otu_taxonomy.txt \
	EVAL_DEPTH=7 \
		./train.sh

silva:
	CLASSIFIER_NAME=silva-132-99 \
	MEMORY_515_806=32000 \
	MEMORY_FULL=64000 \
	SOURCE_SEQS=inputs/silva/silva132_99.fna \
	SOURCE_TAX=inputs/silva/7_level_taxonomy.txt \
	EVAL_DEPTH=7 \
		./train.sh

all: gg silva

clean:
	rm -rf outputs/intermediate/*.qza && \
	rm -rf outputs/logs/*.txt && \
	rm -rf outputs/pretrained-classifiers/*.qza && \
	rm -rf outputs/validation-tests/*.qz*
