#!/usr/bin/env bash

set -e

seqs="outputs/inputs/${CLASSIFIER_NAME}-seqs.qza"
tax="outputs/inputs/${CLASSIFIER_NAME}-tax.qza"
log_path="outputs/logs/%j_%x.txt"

SOURCE_SEQS=gg_13_8_otus/rep_set/99_otus.fasta
SOURCE_TAX=gg_13_8_otus/taxonomy/99_otu_taxonomy.txt

# get data
job_get_data=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_import_seqs" \
        --time 10 \
        --output "${log_path}" \
            wget ftp://greengenes.microbio.me/greengenes_release/gg_13_5/gg_13_8_otus.tar.gz
            tar -zxf gg_13_8_otus.tar.gz
)

# Import
job_import_seqs=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_import_seqs" \
        --dependency "afterok:${job_get_data}" \
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
        --dependency "afterok:${job_get_data}" \
        --time 10 \
        --output "${log_path}" \
            qiime tools import \
                --type "FeatureData[Taxonomy]" \
                --input-path "${SOURCE_TAX}" \
                --output-path "${tax}" \
                --input-format HeaderlessTSVTaxonomyFormat
)
