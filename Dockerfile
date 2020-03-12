FROM nvidia/cuda:10.0-devel-ubuntu18.04
MAINTAINER Cristian Baldi "bld.cris.96@gmail.com"

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN true

# Required packages
RUN apt-get update
RUN apt-get -y install \
    python \
    build-essential \
    python2.7-dev \
    python-pip \
    git \
    libhdf5-dev \
    software-properties-common \
    openssl \
    libssl-dev

# Fix 'sudo: command not found'
# https://github.com/torch/distro/blob/master/install-deps contains 'sudo', but nvidia:cuda removed sudo: https://github.com/crisbal/docker-torch-rnn/issues/9#issuecomment-365362656
RUN apt-get -y install sudo
RUN usermod -aG sudo $(whoami)

# Fix torch installation ( https://github.com/torch/cutorch/issues/797 )
ENV TORCH_NVCC_FLAGS='-D__CUDA_NO_HALF_OPERATORS__'

# Fix torch installation 1 ( https://github.com/torch/cutorch/issues/834 )
RUN apt-get purge cmake
RUN git clone https://github.com/Kitware/CMake.git /home/cmake
RUN mkdir /home/bin
RUN cd /home/cmake && ./bootstrap --prefix=/home/bin && make && sudo make install


# Torch and luarocks
RUN git clone https://github.com/torch/distro.git /home/torch --recursive
# Fix torch installation 2
RUN rm -fr /home/torch/cmake/3.6/Modules/FindCUDA*
COPY atomic.patch /home/torch/extra/cutorch/atomic.patch
RUN cat /home/torch/extra/cutorch/atomic.patch
RUN cd /home/torch/extra/cutorch/ && patch -p1 < /home/torch/extra/cutorch/atomic.patch
# Fix error in ubuntu 18.04 ( https://github.com/torch/torch7/issues/1146 )
RUN sed -i 's/python-software-properties/software-properties-common/g' /home/torch/install-deps
# This tends to print too many warnings for the logging so lets just try and squash them
RUN cd /home/torch && ./clean.sh && bash install-deps && ./install.sh -b

ENV LUA_PATH='/home/.luarocks/share/lua/5.1/?.lua;/home/.luarocks/share/lua/5.1/?/init.lua;/home/torch/install/share/lua/5.1/?.lua;/home/torch/install/share/lua/5.1/?/init.lua;./?.lua;/home/torch/install/share/luajit-2.1.0-beta1/?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua'
ENV LUA_CPATH='/home/.luarocks/lib/lua/5.1/?.so;/home/torch/install/lib/lua/5.1/?.so;./?.so;/usr/local/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so'
ENV PATH=/home/torch/install/bin:$PATH
ENV LD_LIBRARY_PATH=/home/torch/install/lib:$LD_LIBRARY_PATH
ENV DYLD_LIBRARY_PATH=/home/torch/install/lib:$DYLD_LIBRARY_PATH
ENV LUA_CPATH='/home/torch/install/lib/?.so;'$LUA_CPATH

#torch-rnn and python requirements
WORKDIR /home
#RUN git clone https://github.com/jcjohnson/torch-rnn && \
#    pip install -r torch-rnn/requirements.txt

# Fix install torch-rnn requirements in Ubuntu 16.04
# https://github.com/crisbal/docker-torch-rnn/issues/1#issuecomment-324262348
RUN apt-get install -y cython
RUN pip install --user --upgrade pip
# Fix cython version for ubuntu 18.04
RUN pip install --user Cython==0.26.1
RUN pip install --user numpy==1.10.4
RUN pip install --user argparse==1.2.1
# Fix run preprocess in ubuntu 18.04
RUN HDF5_DIR=/usr/lib/x86_64-linux-gnu/hdf5/serial/ pip install --user h5py==2.6.0
RUN pip install --user six==1.10.0
RUN git clone https://github.com/jcjohnson/torch-rnn

#Lua requirements
WORKDIR /home
RUN luarocks install torch
RUN luarocks install nn
RUN luarocks install optim
RUN luarocks install lua-cjson

# Fix run train in ubuntu 18.04 ( https://github.com/deepmind/torch-hdf5/issues/76#issuecomment-357379520 )
RUN git clone https://github.com/anibali/torch-hdf5 /home/torch-hdf5
WORKDIR /home/torch-hdf5
RUN git checkout hdf5-1.10
RUN luarocks make hdf5-0-0.rockspec


#CUDA
WORKDIR /home
# Fix torch installation 3
RUN cd /home/torch/extra/cutorch/ && luarocks make rocks/cutorch-scm-1.rockspec
#RUN luarocks install cutorch
RUN luarocks install cunn

#Done!
WORKDIR /home/torch-rnn