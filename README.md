# Pretrained feature classifier scripts

## Before you begin

Install [RESCRIPt](https://github.com/bokulich-lab/RESCRIPt)

## Quickstart

1. Run `make clean` to clean up the `outputs` dir.
2. Ensure the database source files are present in their respective subdirs
   in `inputs/gg` and `inputs/silva`. Naming matters. Consult the directory
   listing example, below. If the SILVA data files are not present, run `make getsilva` to retrieve and format the SILVA reference data with RESCRIPt. If the GG files are not present, run `make getgg` to retrieve and import the gg_13_8 data.
3. Ensure the `FeatureData[Sequence]` Artifact from the Moving Pictures
   tutorial is present in `inputs/validation-tests`, to be used for comparing
   `FeatureData[Taxonomy]` produced by the new classifiers. Consult the
   directory listing example, below.
4. Copy the taxonomies produced during the last classifier-training session
   from `<prior-session>/outputs/validation-tests` to
   `inputs/validation-tests`. Note: filenames will need to be changed in the
   process. Consult the directory listing example, below.
5. Run `make all`. GG classifiers should be done in <24hr; Silva ~24hrs.

### Proposed directory listing

```
.
├── LICENSE
├── Makefile
├── README.md
├── inputs
│   ├── gg
│   │   ├── gg-13-8-99-seqs.qza
│   │   └── gg-13-8-99-tax.qza
│   ├── silva
│   │   ├── silva-138-99-seqs.qza
│   │   └── silva-138-99-tax.qza
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

## Env

```bash
export SKL_VERSION='0.23.1'
export Q2_VERSION='2020.2'

# prep a throwaway env, for extracting explicit package paths
conda create -n throwaway conda-forge::python==3.6 conda-forge::scikit-learn==$SKL_VERSION
conda list -n throwaway --explicit | grep 'EXPLICIT\|scikit-learn' > packages.txt

# install base env
wget https://data.qiime2.org/distro/core/qiime2-$Q2_VERSION-py36-linux-conda.yml
conda env create -n qiime2-$Q2_VERSION-skl-$SKL_VERSION --file qiime2-$Q2_VERSION-py36-linux-conda.yml

# installed override packages
conda install -n qiime2-$Q2_VERSION-skl-$SKL_VERSION --file packages.txt

# install rescript
# TODO: update to show conda install instructions
conda activate qiime2-$Q2_VERSION-skl-$SKL_VERSION
pip install git+https://github.com/bokulich-lab/RESCRIPt.git

# clean up
conda env remove -n throwaway
rm packages.txt qiime2-$Q2_VERSION-py36-linux-conda.yml
```
