#!/usr/bin/env bash

set -e

seqs="outputs/intermediate/${CLASSIFIER_NAME}-seqs.qza"
seqs_515_806="outputs/intermediate/${CLASSIFIER_NAME}-seqs-515-806.qza"
tax="outputs/intermediate/${CLASSIFIER_NAME}-tax.qza"
classifier="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-nb-classifier.qza"
classifier_515_806="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-515-806-nb-classifier.qza"
test_taxonomy="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy.qza"
test_taxonomy_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-taxonomy.qza"
eval_taxonomy="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy.qzv"
eval_taxonomy_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-taxonomy.qzv"
test_seqs="inputs/validation-tests/mp-rep-seqs.qza"
expected="inputs/validation-tests/${CLASSIFIER_NAME}-expected-taxonomy.qza"
expected_515_806="inputs/validation-tests/${CLASSIFIER_NAME}-expected-515-806-taxonomy.qza"
log_path="outputs/logs/%j_%x.txt"

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

# Extract 515-806
job_extract_reads=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_import_seqs}" \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_extract_reads" \
        --time 90 \
        --output "${log_path}" \
            qiime feature-classifier extract-reads \
                --i-sequences "${seqs}" \
                --p-f-primer GTGCCAGCMGCCGCGGTAA \
                --p-r-primer GGACTACHVGGGTWTCTAAT \
                --o-reads "${seqs_515_806}" \
                --verbose
)

# Train
job_train_515_806=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_extract_reads},afterok:${job_import_tax}" \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_train_515_806" \
        --time 360 \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs_515_806}" \
                --i-reference-taxonomy "${tax}" \
                --o-classifier "${classifier_515_806}" \
                --verbose
)
job_train_full=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_import_seqs},afterok:${job_import_tax}" \
        --mem "${MEMORY_FULL}" \
        --job-name "${CLASSIFIER_NAME}_train_full" \
        --time 1440 \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs}" \
                --i-reference-taxonomy "${tax}" \
                --o-classifier "${classifier}" \
                --verbose
)

# Test
job_classify_515_806=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_train_515_806}" \
        --job-name "${CLASSIFIER_NAME}_classify_515_806" \
        --time 60 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime feature-classifier classify-sklearn \
                --i-classifier "${classifier_515_806}" \
                --i-reads "${test_seqs}" \
                --o-classification "${test_taxonomy_515_806}" \
                --verbose
)
job_classify_full=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_train_full}" \
        --job-name "${CLASSIFIER_NAME}_classify_full" \
        --time 60 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime feature-classifier classify-sklearn \
                --i-classifier "${classifier}" \
                --i-reads "${test_seqs}" \
                --o-classification "${test_taxonomy}" \
                --verbose
)

# Verify
job_eval_taxa_515_806=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_classify_515_806}" \
        --job-name "${CLASSIFIER_NAME}_eval_taxa_515_806" \
        --time 30 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime quality-control evaluate-taxonomy \
                --i-observed-taxa "${test_taxonomy_515_806}" \
                --i-expected-taxa "${expected_515_806}" \
                --p-depth "${EVAL_DEPTH}" \
                --o-visualization "${eval_taxonomy_515_806}" \
                --verbose
)
job_eval_taxa_full=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_classify_full}" \
        --job-name "${CLASSIFIER_NAME}_eval_taxa_full" \
        --time 30 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime quality-control evaluate-taxonomy \
                --i-observed-taxa "${test_taxonomy}" \
                --i-expected-taxa "${expected}" \
                --p-depth "${EVAL_DEPTH}" \
                --o-visualization "${eval_taxonomy}" \
                --verbose
)
