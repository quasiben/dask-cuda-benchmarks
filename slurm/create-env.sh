#!/bin/bash

set -x

module load cuda/11.0.3
export PATH=/gpfs/fs1/bzaitlen/miniconda3/bin:$PATH
source /gpfs/fs1/bzaitlen/miniconda3/bin/activate
ENV=`date +"%Y%m%d-nightly-0.20"`

mamba create -n $ENV -c rapidsai-nightly -c nvidia -c conda-forge \
    automake make libtool pkg-config cudatoolkit=11.0 xarray uvloop \
    libhwloc psutil python=3.8 setuptools pip cython matplotlib seaborn \
    viztracer py-spy \
    cudf=0.20 dask-cudf dask-cuda ipython ipdb pygithub gprof2dot --yes --quiet

[ ! -d "/gpfs/fs1/bzaitlen/miniconda3/envs/$ENV" ] && exit 1

conda activate $ENV

# use dask/distibuted latest
git clone https://github.com/dask/dask.git /tmp/dask
git clone https://github.com/dask/distributed.git /tmp/distributed
#git clone https://github.com/madsbk/distributed.git /tmp/distributed
cd /tmp/dask && git log -n1 && python -m pip install .
#cd /tmp/distributed && git log -n1 && git checkout single_pass_serialization
cd /tmp/distributed
echo "Cythonize Distributed"
python -m pip install -vv --no-deps --install-option="--with-cython=profile" .

git clone https://github.com/openucx/ucx /tmp/ucx
cd /tmp/ucx
git clean -fdx
# apply UCX IB registration cache patches, improves overall
# CUDA IB performance when using a memory pool
# apply UCX IB registration cache patch, improves overall
# CUDA IB performance when using a memory pool
curl -LO https://raw.githubusercontent.com/rapidsai/ucx-split-feedstock/96b29acc28c2c808cd565a385cfd296004aa842b/recipe/cuda-alloc-rcache.patch
git apply cuda-alloc-rcache.patch
./autogen.sh
mkdir -p build
cd build
ls $CUDA_HOME
../contrib/configure-release \
    --prefix="${CONDA_PREFIX}" \
    --with-sysroot \
    --enable-cma \
    --enable-mt \
    --enable-numa \
    --with-gnu-ld \
    --with-rdmacm \
    --with-verbs \
    --with-cuda="${CUDA_HOME}"
make -j install
cd -
git clone https://github.com/rapidsai/ucx-py.git /tmp/ucx-py
cd /tmp/ucx-py
python -m pip install .
