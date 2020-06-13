#!/usr/bin/env bash

set -e

seqs="inputs/${CLASSIFIER_NAME}-seqs.qza"
seqs_515_806_underep="outputs/intermediate/${CLASSIFIER_NAME}-seqs-515-806-undereplicated.qza"
seqs_515_806="outputs/intermediate/${CLASSIFIER_NAME}-seqs-515-806.qza"
tax_515_806="outputs/intermediate/${CLASSIFIER_NAME}-tax-515-806.qza"
tax="inputs/${CLASSIFIER_NAME}-tax.qza"
classifier="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-nb-classifier.qza"
classifier_515_806="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-515-806-nb-classifier.qza"
test_taxonomy="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy.qza"
test_taxonomy_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-taxonomy.qza"
eval_taxonomy="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy.qzv"
eval_taxonomy_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-taxonomy.qzv"
crossval_results="outputs/validation-tests/${CLASSIFIER_NAME}-test-cross-validation.qzv"
crossval_results_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-cross-validation.qzv"
obs_tax="outputs/intermediate/${CLASSIFIER_NAME}-test-cross-validation-predictions.qzv"
obs_tax_515_806="outputs/intermediate/${CLASSIFIER_NAME}-test-515-806-cross-validation-predictions.qzv"
test_seqs="inputs/validation-tests/mp-rep-seqs.qza"
expected="inputs/validation-tests/${CLASSIFIER_NAME}-expected-taxonomy.qza"
expected_515_806="inputs/validation-tests/${CLASSIFIER_NAME}-expected-515-806-taxonomy.qza"
log_path="outputs/logs/%j_%x.txt"


# Extract 515-806
job_extract_reads=$(
    sbatch \
        --parsable \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_extract_reads" \
        --time 90 \
        --output "${log_path}" \
            qiime feature-classifier extract-reads \
                --i-sequences "${seqs}" \
                --p-f-primer GTGCCAGCMGCCGCGGTAA \
                --p-r-primer GGACTACHVGGGTWTCTAAT \
                --o-reads "${seqs_515_806_underep}" \
                --verbose
)

# dereplicate extracted reads
job_derep_seqs=$(
    sbatch \
        --parsable \
        --job-name "${CLASSIFIER_NAME}_derep" \
        --dependency "afterok:${job_extract_reads}" \
        --time 240 \
        --output "${log_path}" \
            qiime rescript dereplicate \
                --i-sequences "${seqs_515_806_underep}" \
                --i-taxa "${tax}" \
                --p-rank-handles "${TAX_TYPE}" \
                --p-mode "uniq" \
                --o-dereplicated-sequences "${seqs_515_806}" \
                --o-dereplicated-taxa "${tax_515_806}"
)

# Train
job_train_515_806=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_derep_seqs}" \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_train_515_806" \
        --time 360 \
        --output "${log_path}" \
            qiime rescript evaluate-fit-classifier \
                --i-sequences "${seqs_515_806}" \
                --i-taxonomy "${tax_515_806}" \
                --o-classifier "${classifier_515_806}" \
                --o-evaluation "${crossval_results_515_806}" \
                --o-observed-taxonomy "${obs_tax_515_806}" \
                --verbose
)
job_train_full=$(
    sbatch \
        --parsable \
        --mem "${MEMORY_FULL}" \
        --job-name "${CLASSIFIER_NAME}_train_full" \
        --time 1440 \
        --output "${log_path}" \
          qiime rescript evaluate-fit-classifier \
              --i-sequences "${seqs}" \
              --i-taxonomy "${tax}" \
              --o-classifier "${classifier}" \
              --o-evaluation "${crossval_results}" \
              --o-observed-taxonomy "${obs_tax}" \
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
