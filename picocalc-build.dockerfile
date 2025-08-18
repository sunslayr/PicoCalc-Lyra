FROM debian:bookworm

ENV DEBIAN_FRONTEND=non-interactive

RUN apt-get update && \
      apt-get -y install sudo

RUN \
    groupadd -g 1000 lyra && useradd -u 1000 -g lyra -G sudo -m -s /bin/bash lyra && \
    sed -i /etc/sudoers -re 's/^%sudo.*/%sudo ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^root.*/root ALL=(ALL:ALL) NOPASSWD: ALL/g' && \
    sed -i /etc/sudoers -re 's/^#includedir.*/## **Removed the include directive** ##"/g' && \
    echo "lyra ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo "Customized the sudoers file for passwordless access to the lyra user!" && \
    echo "lyra user:";  su - lyra -c id


RUN echo "deb http://archive.debian.org/debian/ stretch contrib main non-free" >> /etc/apt/sources.list
RUN apt-get update && apt-get upgrade -y

RUN apt-get install -f git ssh make gcc libssl-dev \
    liblz4-tool expect expect-dev g++ patchelf chrpath gawk texinfo chrpath \
    diffstat binfmt-support qemu-user-static live-build bison flex fakeroot \
    cmake unzip device-tree-compiler ncurses-dev \
    libgucharmap-2-90-dev bzip2 expat gpgv2 cpp-aarch64-linux-gnu libgmp-dev \
    libmpc-dev bc python-is-python3 python2.7 curl file bsdmainutils \
    gcc-arm-linux-gnueabihf libgnutls28-dev -y

RUN ln -sf /usr/bin/python2.7 /usr/bin/python2

CMD bash
