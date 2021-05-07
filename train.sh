#!/usr/bin/env bash

set -e

seqs="inputs/${CLASSIFIER_NAME}-seqs.qza"
seqs_515_806_underep="outputs/intermediate/${CLASSIFIER_NAME}-seqs-515-806-undereplicated.qza"
seqs_515_806="outputs/intermediate/${CLASSIFIER_NAME}-seqs-515-806.qza"
tax_515_806="outputs/intermediate/${CLASSIFIER_NAME}-tax-515-806.qza"
tax="inputs/${CLASSIFIER_NAME}-tax.qza"
weights="inputs/${CLASSIFIER_NAME}-weights.qza"
weights_515_806="inputs/${CLASSIFIER_NAME}-weights-515-806.qza"
classifier="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-nb-classifier.qza"
classifier_515_806="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-515-806-nb-classifier.qza"
classifier_weights="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-nb-weighted-classifier.qza"
classifier_weights_515_806="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-515-806-nb-weighted-classifier.qza"
test_taxonomy_weights="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy_weights.qza"
test_taxonomy_weights_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-weights-515-806-taxonomy.qza"
eval_taxonomy_weights="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy.qzv"
eval_taxonomy_weights_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-taxonomy.qzv"
crossval_results="outputs/validation-tests/${CLASSIFIER_NAME}-test-cross-validation.qzv"
crossval_results_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-cross-validation.qzv"
obs_tax="outputs/intermediate/${CLASSIFIER_NAME}-test-cross-validation-predictions.qza"
obs_tax_515_806="outputs/intermediate/${CLASSIFIER_NAME}-test-515-806-cross-validation-predictions.qza"
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
        --time ${TIME_EXTRACT_READS} \
        --output "${log_path}" \
            qiime feature-classifier extract-reads \
                --i-sequences "${seqs}" \
                --p-f-primer GTGCCAGCMGCCGCGGTAA \
                --p-r-primer GGACTACHVGGGTWTCTAAT \
                --o-reads "${seqs_515_806_underep}" \
                --verbose
)

# Dereplicate extracted reads
job_derep_seqs=$(
    sbatch \
        --parsable \
        --mem "${MEMORY_FULL}" \
        --job-name "${CLASSIFIER_NAME}_derep" \
        --dependency "afterok:${job_extract_reads}" \
        --time 30 \
        --output "${log_path}" \
            qiime rescript dereplicate \
                --i-sequences "${seqs_515_806_underep}" \
                --i-taxa "${tax}" \
                --p-rank-handles "${TAX_TYPE}" \
                --p-mode "uniq" \
                --o-dereplicated-sequences "${seqs_515_806}" \
                --o-dereplicated-taxa "${tax_515_806}" \
                --verbose
)

# Train
job_train_515_806=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_derep_seqs}" \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_train_515_806" \
        --time ${TIME_TRAIN_515_806} \
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
        --time ${TIME_TRAIN_FULL} \
        --output "${log_path}" \
          qiime rescript evaluate-fit-classifier \
              --i-sequences "${seqs}" \
              --i-taxonomy "${tax}" \
              --o-classifier "${classifier}" \
              --o-evaluation "${crossval_results}" \
              --o-observed-taxonomy "${obs_tax}" \
              --verbose
)

# Using q2-feature-classifier to train weighted classifiers until RESCRIPt
# evaluate-fit-classifier is modified to accept weights
job_train_515_806_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_derep_seqs}" \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_train_weights_515_806" \
        --time ${TIME_TRAIN_WEIGHTS} \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs_515_806}" \
                --i-reference-taxonomy "${tax}" \
                --i-class-weight "${weights_515_806}" \
                --o-classifier "${classifier_weights_515_806}" \
                --verbose
)
job_train_full_weights=$(
    sbatch \
        --parsable \
        --mem "${MEMORY_FULL}" \
        --job-name "${CLASSIFIER_NAME}_train_weights_full" \
        --time ${TIME_TRAIN_WEIGHTS} \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs}" \
                --i-reference-taxonomy "${tax}" \
                --i-class-weight "${weights}" \
                --o-classifier "${classifier_weights}" \
                --verbose
)

# Test
job_classify_515_806_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_train_515_806_weights}" \
        --job-name "${CLASSIFIER_NAME}_classify_weights_515_806" \
        --time 60 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime feature-classifier classify-sklearn \
                --i-classifier "${classifier_weights_515_806}" \
                --i-reads "${test_seqs}" \
                --o-classification "${test_taxonomy_weights_515_806}" \
                --verbose
)
job_classify_full_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_train_full_weights}" \
        --job-name "${CLASSIFIER_NAME}_classify_weights_full" \
        --time 60 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime feature-classifier classify-sklearn \
                --i-classifier "${classifier_weights}" \
                --i-reads "${test_seqs}" \
                --o-classification "${test_taxonomy_weights}" \
                --verbose
)

# Verify
job_eval_taxa_515_806_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_classify_515_806_weights}" \
        --job-name "${CLASSIFIER_NAME}_eval_taxa_weights_515_806" \
        --time 30 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime quality-control evaluate-taxonomy \
                --i-observed-taxa "${test_taxonomy_weights_515_806}" \
                --i-expected-taxa "${expected_515_806}" \
                --p-depth "${EVAL_DEPTH}" \
                --o-visualization "${eval_taxonomy_weights_515_806}" \
                --verbose
)
job_eval_taxa_full_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_classify_full_weights}" \
        --job-name "${CLASSIFIER_NAME}_eval_taxa_full_weights" \
        --time 30 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime quality-control evaluate-taxonomy \
                --i-observed-taxa "${test_taxonomy_weights}" \
                --i-expected-taxa "${expected}" \
                --p-depth "${EVAL_DEPTH}" \
                --o-visualization "${eval_taxonomy_weights}" \
                --verbose
)
