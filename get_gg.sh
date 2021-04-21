#!/usr/bin/env bash

set -e

seqs="inputs/${CLASSIFIER_NAME}-seqs.qza"
tax="inputs/${CLASSIFIER_NAME}-tax.qza"
weights="inputs/${CLASSIFIER_NAME}-weights.qza"
weights_515_806="inputs/${CLASSIFIER_NAME}-weights-515-806.qza"
log_path="outputs/logs/%j_%x.txt"

SOURCE_SEQS=gg_13_8_otus/rep_set/99_otus.fasta
SOURCE_TAX=gg_13_8_otus/taxonomy/99_otu_taxonomy.txt

wget ftp://greengenes.microbio.me/greengenes_release/gg_13_5/gg_13_8_otus.tar.gz
tar -zxf gg_13_8_otus.tar.gz
wget "https://github.com/BenKaehler/readytowear/blob/master/data/gg_13_8/515f-806r/average.qza?raw=true" \
    -O "${weights_515_806}"
wget "https://github.com/BenKaehler/readytowear/blob/master/data/gg_13_8/full_length/average.qza?raw=true" \
    -O "${weights}"

# Import
job_import_seqs=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_import_seqs" \
        --time 10 \
        --output "${log_path}" \
            qiime tools import \
                --type "FeatureData[Sequence]" \
                --input-path "${SOURCE_SEQS}" \
                --output-path "${seqs}"
)
job_import_tax=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_import_tax" \
        --time 10 \
        --output "${log_path}" \
            qiime tools import \
                --type "FeatureData[Taxonomy]" \
                --input-path "${SOURCE_TAX}" \
                --output-path "${tax}" \
                --input-format HeaderlessTSVTaxonomyFormat
)
