#!/bin/bash

set -x

module load cuda/11.0.3
export PATH=/gpfs/fs1/bzaitlen/miniconda3/bin:$PATH
source /gpfs/fs1/bzaitlen/miniconda3/bin/activate
ENV=`date +"%Y%m%d-nightly-21.08"`

mamba create -n $ENV -c rapidsai-nightly -c nvidia -c conda-forge \
    automake make libtool pkg-config cudatoolkit=11.0 xarray uvloop viztracer\
    libhwloc psutil python=3.8 setuptools pip cython matplotlib seaborn \
    viztracer py-spy \
    cudf=21.08 dask-cudf dask-cuda ipython ipdb pygithub gprof2dot --yes --quiet

[ ! -d "/gpfs/fs1/bzaitlen/miniconda3/envs/$ENV" ] && exit 1

conda activate $ENV

# use dask/distibuted latest
git clone https://github.com/dask/dask.git /tmp/dask
git clone https://github.com/dask/distributed.git /tmp/distributed
cd /tmp/dask && git log -n1 && python -m pip install .
cd /tmp/distributed
echo "Cythonize Distributed"
python -m pip install -vv --no-deps --install-option="--with-cython=profile" .

git clone https://github.com/openucx/ucx /tmp/ucx
cd /tmp/ucx
curl -LO https://gist.githubusercontent.com/pentschev/d3da75202667fa7e9e87abbe8dc3f448/raw/cb526bf279d40f20d3f22172fd8e1cc9735c8033/cuda-alloc-rcache-aligned-1.11.patch
git apply cuda-alloc-rcache-aligned-1.11.patch
git clean -fdx
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
