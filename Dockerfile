FROM debian:12

# Install dependencies for building GCC
RUN apt-get update && apt-get install -y \
    build-essential git autoconf automake bison flex texinfo libgmp-dev libmpfr-dev libmpc-dev

# Copy the local GCC source into the image
COPY gcc /usr/src/gcc
WORKDIR /usr/src/gcc

# Prepare GCC prerequisites
RUN ./contrib/download_prerequisites

# Configure only C and C++ for now, no multilib
RUN ./configure --disable-multilib --enable-languages=c,c++

# Build GCC (gcc0 stage)
RUN make -j$(nproc)
RUN make install
