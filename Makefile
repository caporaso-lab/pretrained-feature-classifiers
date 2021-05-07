.PHONY: gg silva all clean getgg getsilva

gg:
	CLASSIFIER_NAME=gg-13-8-99 \
	MEMORY_515_806=16000 \
	MEMORY_FULL=32000 \
	EVAL_DEPTH=7 \
	TAX_TYPE=greengenes \
	TIME_EXTRACT_READS=45 \
	TIME_TRAIN_515_806=120 \
	TIME_TRAIN_FULL=230 \
	TIME_TRAIN_WEIGHTS=75 \
		./train.sh

silva:
	CLASSIFIER_NAME=silva-138-99 \
	MEMORY_515_806=64000 \
	MEMORY_FULL=64000 \
	EVAL_DEPTH=7 \
	TAX_TYPE=silva \
	TIME_EXTRACT_READS=75 \
	TIME_TRAIN_515_806=3300 \
	TIME_TRAIN_FULL=8640 \
	TIME_TRAIN_WEIGHTS=1440 \
		./train.sh

getgg:
	CLASSIFIER_NAME=gg-13-8-99 \
		./get_gg.sh

getsilva:
	VERSION=138 \
	TARGET=SSURef_NR99 \
	MEMORY=64000 \
	CLASSIFIER_NAME=silva-138-99 \
		./get_silva.sh

all: gg silva

clean:
	rm -rf outputs/intermediate/*.qza && \
	rm -rf outputs/logs/*.txt && \
	rm -rf outputs/pretrained-classifiers/*.qza && \
	rm -rf outputs/validation-tests/*.qz*
