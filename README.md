# Pretrained feature classifier scripts

## Before you begin

Install [RESCRIPt](https://github.com/bokulich-lab/RESCRIPt)

## Quickstart

1. `make getgg` / `make getsilva` will ensure you have the input data.
2. TODO: validation tests?
3. `make gg` / `make silva` will submit jobs to train the classifiers.
   `make all` will submit all jobs for both databases.

### Proposed directory listing

TODO: is this section still necessary?

```
.
├── LICENSE
├── Makefile
├── README.md
├── inputs
│   └── validation-tests
│       ├── gg-13-8-99-expected-515-806-taxonomy.qza
│       ├── gg-13-8-99-expected-taxonomy.qza
│       ├── mp-rep-seqs.qza
│       ├── silva-138-99-expected-515-806-taxonomy.qza
│       └── silva-138-99-expected-taxonomy.qza
├── outputs
│   ├── intermediate
│   ├── logs
│   ├── pretrained-classifiers
│   └── validation-tests
└── train.sh
```

## Manually `Updating scikit-learn`

```bash
export SKL_VERSION='0.XY.Z'
export Q2_VERSION='20AB.C'

# prep a throwaway env, for extracting explicit package paths
conda create -n throwaway conda-forge::python==3.8 conda-forge::scikit-learn==$SKL_VERSION
conda list -n throwaway --explicit | grep 'EXPLICIT\|scikit-learn' > packages.txt

# install base env
wget https://data.qiime2.org/distro/core/qiime2-$Q2_VERSION-py38-linux-conda.yml
conda env create -n qiime2-$Q2_VERSION-skl-$SKL_VERSION --file qiime2-$Q2_VERSION-py38-linux-conda.yml

# installed override packages
conda install -n qiime2-$Q2_VERSION-skl-$SKL_VERSION --file packages.txt

# clean up
conda env remove -n throwaway
rm packages.txt qiime2-$Q2_VERSION-py38-linux-conda.yml
```
