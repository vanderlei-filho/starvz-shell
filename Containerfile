FROM fedora:40

ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:${PKG_CONFIG_PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/local/lib64:${LD_LIBRARY_PATH}"
ENV PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin:${PATH}"

# Install compilers and base dependencies
RUN dnf -y update \
    && dnf -y upgrade \
    && dnf install -y \
        R \
        R-devel \
        gcc gcc-c++ \
        cmake \
        git \
        wget \
        tar \
        bzip2 \
        pkg-config \
        automake autoconf libtool \
        flex \
        bison \
        libcurl-devel \
        openssl-devel \
        libxml2-devel \
        libgit2-devel \
        cairo-devel \
        pango-devel \
        freetype-devel \
        fontconfig-devel \
        harfbuzz-devel \
        fribidi-devel \
        libjpeg-turbo-devel \
        libpng-devel \
        libtiff-devel \
        nodejs \
        npm \
        graphviz \
        recutils \
        fmt-devel \
        flex-devel \
        boost-devel \
        glibc-common \
    && dnf clean all

# Re-install HWLOC
# Why? This is needed for correct CUDA support in StarPU
RUN cd /tmp \
    && dnf -y remove hwloc hwloc-devel \
    && wget https://download.open-mpi.org/release/hwloc/v2.12/hwloc-2.12.0.tar.bz2 \
    && tar -xf hwloc-2.12.0.tar.bz2 \
    && cd hwloc-2.12.0 \
    && ./configure \
        --prefix=/usr/local \
        #--enable-cuda \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf /tmp/hwloc-*

# Install OpenMPI
RUN cd /tmp \
    && wget https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.7.tar.bz2 \
    && tar xf openmpi-5.0.7.tar.bz2 \
    && cd openmpi-5.0.7 \
    && ./configure \
        --prefix=/usr/local \
        --disable-mpi-fortran \
        --enable-mca-no-build=btl-uct \
        --enable-mpi-thread-multiple \
        --enable-shared \
        --enable-static \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf /tmp/openmpi-*

# Install FxT for StarPU performance analysis
RUN cd /tmp \
    && wget https://salsa.debian.org/debian/fxt/-/archive/master/fxt-master.tar.gz \
    && tar -xzf fxt-master.tar.gz \
    && cd fxt-master \
    && ./configure \
        --prefix=/usr/local \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf /tmp/fxt-*

# Install StarPU with fully distributed MPI support and FxT enabled
ENV STARPU_MAX_CPUS=512
ENV STARPU_MAX_CUDA_DEVICES=16

RUN cd /tmp \
    && wget https://files.inria.fr/starpu/starpu-1.4.7/starpu-1.4.7.tar.gz \
    && tar xzf starpu-1.4.7.tar.gz \
    && cd starpu-1.4.7 \
    && ./configure \
        --prefix=/usr/local \
        --disable-opencl \
        --disable-build-examples \
        --disable-build-doc \
        --enable-mpi \
        --enable-maxcpus=${STARPU_MAX_CPUS} \
        --enable-maxcudadev=${STARPU_MAX_CUDA_DEVICES} \
        --with-fxt=/usr/local \
        --with-mpicc=/usr/local/bin/mpicc \
        --with-hwloc=/usr/local \
    && make -j$(nproc) \
    && make install \
    && ldconfig \
    && cd / \
    && rm -rf /tmp/starpu-*

# Install PajeNG
RUN cd /tmp \
    && git clone https://github.com/schnorr/pajeng.git \
    && cd pajeng \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/pajeng \
    && ldconfig

# Install R packages
RUN R -e "options(Ncpus=parallel::detectCores()); \
    install.packages('devtools', repos='https://cloud.r-project.org/', dependencies=TRUE)"

RUN R -e "install.packages(c('tidyverse', 'ggplot2', 'dplyr', 'readr', \
    'purrr', 'jsonlite', 'yaml', 'data.table', 'gridExtra', 'cowplot', \
    'patchwork', 'viridis', 'scales', 'zoo', 'Rcpp', 'car'), \
    repos='https://cloud.r-project.org/', dependencies=TRUE)"

# Install StarVZ
RUN R -e "devtools::install_github('schnorr/starvz', dependencies=TRUE, upgrade='always')"

ENV PATH="/usr/lib64/R/library/starvz/tools:${PATH}"

# Create workspace directory for volume mount
RUN mkdir -p /workspace

WORKDIR /workspace

CMD ["/bin/bash"]
