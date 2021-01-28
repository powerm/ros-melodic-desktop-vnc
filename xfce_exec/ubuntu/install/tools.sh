#!/usr/bin/env bash
### every exit != 0 fails the script
set -e

echo "Install some common tools for further installation"
apt-get update 
apt-get install -y \
    tmux \
    vim \
    wget \
    git \
    gedit \
    net-tools \
    locales \
    bzip2 \
    unzip \
    openssh-client \
    apt-utils \
    usbutils \
    python-pip \
    python-dev\
    ffmpeg \
    python-numpy  #used for websockify/novnc
apt-get clean -y

echo "generate locales für en_US.UTF-8"
locale-gen en_US.UTF-8