FROM ubuntu:20.04

ENV UID=1000
ENV GID=1000
ENV USER="rs"

# install all dependencies
ENV DEBIAN_FRONTEND="noninteractive"
RUN apt-get update \
  && apt-get install --yes --no-install-recommends curl unzip sed git bash xz-utils libglvnd0 ssh xauth x11-xserver-utils libpulse0 libxcomposite1 libgl1-mesa-glx sudo \
  gettext libtool libtool-bin build-essential autoconf automake cmake g++ pkg-config unzip xorg-dev ca-certificates \
  && rm -rf /var/lib/{apt,dpkg,cache,log}

# create user
RUN groupadd --gid $GID $USER \
  && useradd -s /bin/bash --uid $UID --gid $GID -m $USER \
  && echo $USER ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER \
  && chmod 0440 /etc/sudoers.d/$USER


USER $USER
WORKDIR /home/$USER

# get zig
RUN curl -O https://ziglang.org/download/0.9.1/zig-linux-x86_64-0.9.1.tar.xz
RUN tar xf zig-linux-x86_64-0.9.1.tar.xz 

# get the source
RUN mkdir slides
COPY build.zig slides/
COPY assets/ slides/assets/
COPY pptx_template/ slides/pptx_template/
COPY src/ slides/src/
COPY ZT/ slides/ZT

# build slides
RUN cd slides && ~/zig-linux-x86_64-0.9.1/zig build 

# run slides
ENTRYPOINT ["./slides/zig-out/bin/slides"]
