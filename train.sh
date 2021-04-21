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
classifier_q2fc="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-nb-classifier-BACKUP-q2fc.qza"
classifier_515_806_q2fc="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-515-806-nb-classifier-BACKUP-q2fc.qza"
classifier_weights_q2fc="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-nb-weighted-classifier.qza"
classifier_weights_515_806_q2fc="outputs/pretrained-classifiers/${CLASSIFIER_NAME}-515-806-nb-weighted-classifier.qza"
test_taxonomy="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy.qza"
test_taxonomy_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-taxonomy.qza"
test_taxonomy_weights="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy_weights.qza"
test_taxonomy_weights_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-weights-515-806-taxonomy.qza"
eval_taxonomy="outputs/validation-tests/${CLASSIFIER_NAME}-test-taxonomy.qzv"
eval_taxonomy_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-taxonomy.qzv"
crossval_results="outputs/validation-tests/${CLASSIFIER_NAME}-test-cross-validation.qzv"
crossval_results_515_806="outputs/validation-tests/${CLASSIFIER_NAME}-test-515-806-cross-validation.qzv"
obs_tax="outputs/intermediate/${CLASSIFIER_NAME}-test-cross-validation-predictions.qza"
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
        --mem "${MEMORY_FULL}" \
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
        --time 2880 \
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
        --time 4320 \
        --output "${log_path}" \
          qiime rescript evaluate-fit-classifier \
              --i-sequences "${seqs}" \
              --i-taxonomy "${tax}" \
              --o-classifier "${classifier}" \
              --o-evaluation "${crossval_results}" \
              --o-observed-taxonomy "${obs_tax}" \
              --verbose
)

# Train with q2-feature-classifier as a back-up when time is running short.
# RESCRIPt uses q2-feature-classifier to train a classifier as part of a longer
# pipeline that evaluates the classifier — this can take some time as it
# classifies every sequence in the reference database! Usually greengenes will
# complete with RESCRIPt in just a few hours (not much longer than with q2-dc),
# but the long runtimes set above are for the sake of SILVA, which can take a
# day or a few. The classifiers should give the same results, but RESCRIPt will
# also output its own validation results to determine overall database quality.
job_train_515_806=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_derep_seqs}" \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_train_515_806_q2fc" \
        --time 360 \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs_515_806}" \
                --i-reference-taxonomy "${tax}" \
                --o-classifier "${classifier_515_806_q2fc}" \
                --verbose
)
job_train_full=$(
    sbatch \
        --parsable \
        --mem "${MEMORY_FULL}" \
        --job-name "${CLASSIFIER_NAME}_train_full_q2fc" \
        --time 1440 \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs}" \
                --i-reference-taxonomy "${tax}" \
                --o-classifier "${classifier_q2fc}" \
                --verbose
)


# Using q2-feature-classifier to train weighted classifiers until RESCRIPt
# evaluate-fit-classifier is modified to accept weights
job_train_515_806_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_derep_seqs}" \
        --mem "${MEMORY_515_806}" \
        --job-name "${CLASSIFIER_NAME}_train_weights_515_806_q2fc" \
        --time 360 \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs_515_806}" \
                --i-reference-taxonomy "${tax}" \
                --i-class-weight "${weights_515_806}" \
                --o-classifier "${classifier_weights_515_806_q2fc}" \
                --verbose
)
job_train_full_weights=$(
    sbatch \
        --parsable \
        --mem "${MEMORY_FULL}" \
        --job-name "${CLASSIFIER_NAME}_train_weights_full_q2fc" \
        --time 1440 \
        --output "${log_path}" \
            qiime feature-classifier fit-classifier-naive-bayes \
                --i-reference-reads "${seqs}" \
                --i-reference-taxonomy "${tax}" \
                --i-class-weight "${weights}" \
                --o-classifier "${classifier_weights_q2fc}" \
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
job_classify_515_806_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_train_515_806_weights}" \
        --job-name "${CLASSIFIER_NAME}_classify_weights_515_806" \
        --time 60 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime feature-classifier classify-sklearn \
                --i-classifier "${classifier_weights_515_806_q2fc}" \
                --i-reads "${test_seqs}" \
                --o-classification "${test_taxonomy_weights_515_806}" \
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
job_classify_full_weights=$(
    sbatch \
        --parsable \
        --dependency "afterok:${job_train_full_weights}" \
        --job-name "${CLASSIFIER_NAME}_classify_weights_full" \
        --time 60 \
        --mem "${MEMORY_515_806}" \
        --output "${log_path}" \
            qiime feature-classifier classify-sklearn \
                --i-classifier "${classifier_weights_q2fc}" \
                --i-reads "${test_seqs}" \
                --o-classification "${test_taxonomy_weights}" \
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
