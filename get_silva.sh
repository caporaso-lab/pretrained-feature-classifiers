#!/usr/bin/env bash

set -e

raw_seqs="outputs/intermediate/${CLASSIFIER_NAME}-raw-seqs.qza"
culled_seqs="outputs/intermediate/${CLASSIFIER_NAME}-culled-seqs.qza"
filtered_seqs="outputs/intermediate/${CLASSIFIER_NAME}-filtered-seqs.qza"
discarded_seqs="outputs/intermediate/${CLASSIFIER_NAME}-length-discarded-seqs.qza"
seqs="inputs/${CLASSIFIER_NAME}-seqs.qza"
full_tax="outputs/intermediate/${CLASSIFIER_NAME}-tax-underep.qza"
tax="inputs/${CLASSIFIER_NAME}-tax.qza"
weights="inputs/${CLASSIFIER_NAME}-weights.qza"
weights_515_806="inputs/${CLASSIFIER_NAME}-weights-515-806.qza"
log_path="outputs/logs/%j_%x.txt"

wget "https://github.com/BenKaehler/readytowear/blob/master/data/silva_138/515f-806r/average.qza?raw=true" \
    -O "${weights_515_806}"
wget "https://github.com/BenKaehler/readytowear/blob/master/data/silva_138/full_length/average.qza?raw=true" \
    -O "${weights}"

# Import
job_get_data=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_get_data" \
        --time 90 \
        --mem "${MEMORY}" \
        --output "${log_path}" \
            qiime rescript get-silva-data \
                --p-version "${VERSION}" \
                --p-target "${TARGET}" \
                --p-include-species-labels \
                --o-silva-sequences "${raw_seqs}" \
                --o-silva-taxonomy "${full_tax}"
)

# Cull
job_cull_seqs=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_cull_seqs" \
        --dependency "afterok:${job_get_data}" \
        --time 120 \
        --mem "${MEMORY}" \
        --output "${log_path}" \
            qiime rescript cull-seqs \
                --i-sequences "${raw_seqs}" \
                --o-clean-sequences "${culled_seqs}"
)

# filter by length
job_filter_seqs=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_filter_seqs" \
        --dependency "afterok:${job_cull_seqs}" \
        --time 120 \
        --output "${log_path}" \
            qiime rescript filter-seqs-length-by-taxon \
                --i-sequences "${culled_seqs}" \
                --i-taxonomy "${full_tax}" \
                --p-labels Archaea Bacteria Eukaryota \
                --p-min-lens 900 1200 1400 \
                --o-filtered-seqs "${filtered_seqs}" \
                --o-discarded-seqs "${discarded_seqs}"
)

# dereplicate
job_derep_seqs=$(
    sbatch \
        --parsable \
        --mem "${MEMORY}" \
        --job-name "${CLASSIFIER_NAME}_derep" \
        --dependency "afterok:${job_filter_seqs}" \
        --time 240 \
        --output "${log_path}" \
            qiime rescript dereplicate \
                --i-sequences "${filtered_seqs}" \
                --i-taxa "${full_tax}" \
                --p-rank-handles "silva" \
                --p-mode "uniq" \
                --o-dereplicated-sequences "${seqs}" \
                --o-dereplicated-taxa "${tax}"
)
