FROM debian:12

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    flex \
    bison \
    texinfo \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    git \
  && rm -rf /var/lib/apt/lists/*

# Copy your GCC source into the container
COPY gcc-src /gcc-src
WORKDIR /gcc-src

# # Configure GCC (disable bootstrap, build just once)
# RUN mkdir build && cd build \
#     && ../configure --disable-bootstrap --disable-multilib --enable-languages=c,c++ \
#     && make -j$(nproc) \
#     && make install

CMD ["/bin/bash"]
