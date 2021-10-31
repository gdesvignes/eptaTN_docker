# Copyright (C) 2016, 2017 by Maciej Serylak
# Copyright (C) 2021 by Gregory Desvignes

# Licensed under the Academic Free License version 3.0
# This program comes with ABSOLUTELY NO WARRANTY.
# You are free to modify and redistribute this code as long
# as you do not remove the above attribution and reasonably
# inform receipients that you have modified the original work.




FROM ubuntu:focal

MAINTAINER Gregory Desvignes "gdesvignes.astro@gmail.com"

# Suppress debconf warnings
ENV DEBIAN_FRONTEND noninteractive

# Switch account to root and adding user accounts and password
USER root
RUN echo "root:V153k!" | chpasswd

# Create psr user which will be used to run commands with reduced privileges.
RUN adduser --disabled-password --gecos 'unprivileged user' psr && \
    echo "psr:psr" | chpasswd && \
    mkdir -p /home/psr/.ssh && \
    chown -R psr:psr /home/psr/.ssh

# Create space for ssh deamozshn and update the system
RUN echo 'deb [arch=amd64] http://archive.ubuntu.com/ubuntu focal main multiverse' >> /etc/apt/sources.list && \
    echo 'deb [arch=amd64] http://mirrors.kernel.org/ubuntu/ focal main multiverse' >> /etc/apt/sources.list && \
    mkdir /var/run/sshd && \
    apt-get -y check && \
    apt-get -y update && \
    apt-get install -y apt-utils apt-transport-https software-properties-common &&\
    apt-get -y update --fix-missing && \
    apt-get -y upgrade &&\
    apt-get -y update --fix-missing

RUN apt-get -y install \
    apt-utils \
    autoconf \
    automake \
    autotools-dev \
    binutils-dev \
    build-essential \
    cmake \
    cmake-curses-gui \
    cmake-data \
    cpp \
    csh \
    curl \
    cvs \
    cython \
    dkms \
    emacs\
    exuberant-ctags \
    f2c \
    fort77 \
    g++ \
    gawk \
    gcc \
    gfortran \
    git \
    git-core \
    gsl-bin \
    htop \
    hwloc \
    libatlas-base-dev \
    libblas-dev \
    liblapack-dev \
    libc-dev-bin \
    libc6-dev \
    libfreetype6 \
    libfreetype6-dev \
    libgd-dev \
    libglib2.0-0 \
    libglib2.0-dev \
    libgmp3-dev \
    libgsl-dev \
    liblapack-dev \
    liblapack-pic \
    liblapack-test \
    liblapack3 \
    liblapacke \
    liblapacke-dev \
    libltdl-dev \
    libltdl7 \
    libmpich-dev \
    libopenblas-base \
    libopenblas-dev \
    libopenmpi-dev \
    libreadline-dev \ 
    libquadmath0-ppc64el-cross \
    libsocket++-dev \
    libsocket++1 \
    libssl-dev \
    libtool \
    llvm-6.0 \
    llvm-6.0-dev \
    llvm-6.0-examples \
    llvm-6.0-runtime \
    locate \
    lsof \
    m4 \
    make \
    man \
    mc \
    nano \
    numactl \
    openmpi-bin \
    openmpi-common \
    openssh-server \
    pbzip2 \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    screen \
    source-highlight \
    subversion \
    tcsh \
    vim \
    wget \
    zlib1g-dev \
    software-properties-common \
    libopenblas-base\
    libopenblas-dev\
    rsync

# Install python modules

RUN pip3 install pip -U && \
    pip3 install setuptools -U && \
    pip3 install datetime -U
    
# Set python3 as default version
RUN update-alternatives --install  /usr/bin/python python /usr/bin/python3 1

# Switch account to psr
USER psr

# Define home, psrhome, OSTYPE and create the directory
ENV HOME /home/psr
ENV PSRHOME /home/psr/software
ENV OSTYPE linux
RUN mkdir -p /home/psr/software

# Downloading all source codes
WORKDIR $PSRHOME
RUN wget --no-check-certificate https://www.imcce.fr/content/medias/recherche/equipes/asd/calceph/calceph-2.3.2.tar.gz && \
    tar -xvvf calceph-2.3.2.tar.gz -C $PSRHOME && \
    git clone https://bitbucket.org/psrsoft/tempo2.git && \
    git clone https://github.com/JohannesBuchner/MultiNest  && \
    git clone https://github.com/PolyChord/PolyChordLite.git && \
   git clone https://github.com/gdesvignes/TempoNest.git


# tempo2
ENV TEMPO2=$PSRHOME"/tempo2/T2runtime" \
    PATH=$PATH:$PSRHOME"/tempo2/T2runtime/bin" \
    C_INCLUDE_PATH=$C_INCLUDE_PATH:$PSRHOME"/tempo2/T2runtime/include" \
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PSRHOME"/tempo2/T2runtime/lib"
WORKDIR $PSRHOME/tempo2
# A fix to get rid of: returned a non-zero code: 126.
RUN sync && perl -pi -e 's/chmod \+x/#chmod +x/' bootstrap
RUN ./bootstrap && \
    ./configure  --enable-shared --enable-static --with-pic F77=gfortran  && \
    make -j $(nproc) && \
    make install && \
    make plugins-install
WORKDIR $PSRHOME/tempo2/T2runtime/clock
RUN touch meerkat2gps.clk && \
    echo "# UTC(meerkat) UTC(GPS)" > meerkat2gps.clk && \
    echo "#" >> meerkat2gps.clk && \
    echo "50155.00000 0.0" >> meerkat2gps.clk && \
    echo "58000.00000 0.0" >> meerkat2gps.clk

# PolyChordLite
WORKDIR $PSRHOME/PolyChordLite
RUN make all
ENV PC_DIR="$PSRHOME/PolyChordLite/lib"

#Installing TempoNest and relevant dependencies
WORKDIR $PSRHOME
WORKDIR $PSRHOME/MultiNest/build
RUN cmake .. && make && ln -s $PSRHOME/MultiNest/lib/libmultinest_mpi.so $PSRHOME/MultiNest/lib/libnest3.so
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"$PSRHOME/MultiNest/lib":"/usr/lib/x86_64-linux-gnu/openmpi/lib/" \
    CFLAGS="$CFLAGS -I$PSRHOME/MultiNest/include" \
    CPPFLAGS="$CPPFLAGS -I$PSRHOME/MultiNest/include" \
    MULTINEST_DIR="$PSRHOME/MultiNest/lib"

#WORKDIR $PSRHOME/TempoNest/PolyChord
#RUN make && mv src/libchord.a $PSRHOME/MultiNest/lib/

WORKDIR $PSRHOME/TempoNest
RUN git checkout --track origin/newPC && sh ./autogen.sh && ./configure --prefix=$PSRHOME/TempoNest CC=mpicc CXX=mpicxx F77=mpifort FC=mpifort CXXFLAGS=-std=c++14 LDFLAGS=-L$PC_DIR && make temponest && make temponest-install


USER psr

# Clean downloaded source codes
WORKDIR $PSRHOME
RUN rm -rf ./*.bz2 ./*.gz ./*.xz ./*.ztar ./*.zip

# Put in file with all environmental variables
WORKDIR $HOME
RUN echo "" >> .bashrc && \
    echo "if [ -e \$HOME/.mysetenv.bash ]; then" >> .bashrc && \
    echo "   source \$HOME/.mysetenv.bash" >> .bashrc && \
    echo "fi" >> .bashrc && \
    echo "" >> .bashrc && \
    echo "alias rm='rm -i'" >> .bashrc && \
    echo "alias mv='mv -i'" >> .bashrc && \
    echo "alias ldc='ls -lrt'" >> .bashrc && \
    echo "# Set up PS1" >> .mysetenv.bash && \
    echo "export PS1=\"\u@\h [\$(date +%d\ %b\ %Y\ %H:%M)] \w> \"" >> .mysetenv.bash && \
    echo "" >> .mysetenv.bash && \
    echo "# Define home, psrhome, software, OSTYPE" >> .mysetenv.bash && \
    echo "export HOME=/home/psr" >> .mysetenv.bash && \
    echo "export PSRHOME=/home/psr/software" >> .mysetenv.bash && \
    echo "export OSTYPE=linux" >> .mysetenv.bash && \
    echo "" >> .mysetenv.bash && \
    echo "# Up arrow search" >> .mysetenv.bash && \
    echo "export HISTFILE=\$HOME/.bash_eternal_history" >> .mysetenv.bash && \
    echo "export HISTFILESIZE=" >> .mysetenv.bash && \
    echo "export HISTSIZE=" >> .mysetenv.bash && \
    echo "export HISTCONTROL=ignoreboth" >> .mysetenv.bash && \
    echo "export HISTIGNORE=\"l:ll:lt:ls:bg:fg:mc:history::ls -lah:..:ls -l;ls -lh;lt;la\"" >> .mysetenv.bash && \
    echo "export HISTTIMEFORMAT=\"%F %T \"" >> .mysetenv.bash && \
    echo "export PROMPT_COMMAND=\"history -a\"" >> .mysetenv.bash && \
    echo "bind '\"\e[A\":history-search-backward'" >> .mysetenv.bash && \
    echo "bind '\"\e[B\":history-search-forward'" >> .mysetenv.bash && \

    echo "" >> .mysetenv.bash && \
    echo "# tempo" >> .mysetenv.bash && \
    echo "export TEMPO=\$PSRHOME/tempo" >> .mysetenv.bash && \
    echo "export PATH=\$PATH:\$TEMPO/bin" >> .mysetenv.bash && \
    echo "" >> .mysetenv.bash && \

    echo "# tempo2" >> .mysetenv.bash && \
    echo "export TEMPO2=\$PSRHOME/tempo2/T2runtime" >> .mysetenv.bash && \
    echo "export PATH=\$PATH:\$TEMPO2/bin" >> .mysetenv.bash && \
    echo "export C_INCLUDE_PATH=\$C_INCLUDE_PATH:\$TEMPO2/include" >> .mysetenv.bash && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:\$TEMPO2/lib" >> .mysetenv.bash && \
    echo "" >> .mysetenv.bash && \

    echo "# TempoNest" >> .mysetenv.bash && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/home/psr/software/MultiNest/lib" >> .mysetenv.bash && \
    echo "export MULTINEST_DIR=\$PSRHOME/MultiNest/lib" >> .mysetenv.bash && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu/openmpi/lib/" >> .mysetenv.bash && \

    echo "# PolyChordLite" >> .mysetenv.bash && \
    echo "export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:/home/psr/software/PolyChordLite/lib" >> .mysetenv.bash && \
    echo "export PC_DIR=\$PSRHOME/PolyChordLite/lib" >> .mysetenv.bash && \

    echo "alias emacs='emacs -nw'" >> .mysetenv.bash  && \
    echo "alias emcas='emacs'" >> .mysetenv.bash  && \
    echo "alias em='emacs'" >> .mysetenv.bash  && \
    echo "alias mroe='more'" >> .mysetenv.bash  && \


    echo "source \$HOME/.bashrc" >> $HOME/.zshrc && \



    /bin/bash -c "source \$HOME/.bashrc" 



# Update database for locate and run sshd server and expose port 22
USER root
RUN sed 's/X11Forwarding yes/X11Forwarding yes\nX11UseLocalhost no/' -i /etc/ssh/sshd_config && \
    echo "if [ -e \/home/psr/.mysetenv.bash ]; then" >> .bashrc && \
    echo "   source \/home/psr/.mysetenv.bash" >> .bashrc && \
    echo "fi" >> .bashrc && \
    echo "" >> .bashrc && \
    echo "alias rm='rm -i'" >> .bashrc && \
    echo "alias mv='mv -i'" >> .bashrc 
RUN updatedb
EXPOSE 22
EXPOSE 9000
CMD ["/usr/sbin/sshd", "-D"]
