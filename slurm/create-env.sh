#!/bin/bash

set -x

module load cuda/10.2.89.0
export PATH=/gpfs/fs1/bzaitlen/miniconda3/bin:$PATH
source /gpfs/fs1/bzaitlen/miniconda3/bin/activate
ENV=`date +"%Y%m%d-nightly-0.18"`

mamba create -n $ENV -c rapidsai-nightly -c nvidia -c conda-forge \
    automake make libtool pkg-config cudatoolkit=10.2 xarray uvloop \
    libhwloc psutil python=3.8 setuptools pip cython matplotlib seaborn \
    cudf=0.18 dask-cudf dask-cuda ipython ipdb pygithub gprof2dot --yes --quiet

conda activate $ENV

# use dask/distibuted latest
git clone https://github.com/dask/dask.git /tmp/dask
git clone https://github.com/dask/distributed.git /tmp/distributed
cd /tmp/dask && git log -n1 && python -m pip install .
cd /tmp/distributed && git log -n1
echo "Cythonize Distributed"
python -m pip install -vv --no-deps --install-option="--with-cython=profile" .

git clone https://github.com/openucx/ucx /tmp/ucx
cd /tmp/ucx
git checkout v1.8.x
git clean -fdx
# apply UCX IB registration cache patches, improves overall
# CUDA IB performance when using a memory pool
curl -LO https://raw.githubusercontent.com/rapidsai/ucx-split-feedstock/bd0377fb7363fd0ddbc3d506ae3414ef6f2e2f50/recipe/add-page-alignment.patch
curl -LO https://raw.githubusercontent.com/rapidsai/ucx-split-feedstock/bd0377fb7363fd0ddbc3d506ae3414ef6f2e2f50/recipe/ib_registration_cache.patch
git apply ib_registration_cache.patch && git apply add-page-alignment.patch
./autogen.sh
mkdir -p build
cd build
ls $CUDA_HOME
../contrib/configure-release \
    --prefix="${CONDA_PREFIX}" \
    --enable-cma \
    --enable-mt \
    --enable-numa \
    --with-gnu-ld \
    --with-cm \
    --with-rdmacm \
    --with-verbs \
    --with-rc \
    --with-ud \
    --with-dc \
    --with-dm \
    --with-cuda="${CUDA_HOME}"
make -j install
cd -
git clone https://github.com/rapidsai/ucx-py.git /tmp/ucx-py
cd /tmp/ucx-py
python -m pip install .
