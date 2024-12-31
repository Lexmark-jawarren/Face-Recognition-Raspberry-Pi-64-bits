# Use an official Ubuntu as a parent image
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Set the working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    cmake wget \
    build-essential gcc g++ \
    libprotobuf-dev protobuf-compiler \
    git \
    libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/Tencent/ncnn.git

RUN mkdir ncnn/build

WORKDIR /app/ncnn/build

RUN cmake -D NCNN_DISABLE_RTTI=OFF -D NCNN_BUILD_TOOLS=ON \
-D CMAKE_TOOLCHAIN_FILE=../toolchains/aarch64-linux-gnu.toolchain.cmake .. && \
make -j4 && make install

RUN cp -r install/include/ncnn /usr/local/include/ncnn
RUN mkdir -p /usr/local/lib/ncnn
RUN cp -r install/lib/libncnn.a /usr/local/lib/ncnn/libncnn.a

WORKDIR /app

# Copy the local repository files to the container
COPY . /app

# Build the project using CMake
RUN mkdir build && cd build && cmake .. && make

# Command to run the application
CMD ["./FaceRecognition"]