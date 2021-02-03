# This Dockerfile is used to build an headles vnc image based on Ubuntu

#####################################

# Base image

#####################################

FROM ubuntu:18.04 AS base

###########################

ENV DEBIAN_FRONTEND=noninteractive
ENV REFRESHED_AT 2021-01-28

LABEL io.k8s.description="Headless VNC Container with Xfce window manager, firefox and chromium" \
      io.k8s.display-name="Headless VNC Container based on Ubuntu" \
      io.openshift.expose-services="6901:http,5901:xvnc" \
      io.openshift.tags="vnc, ubuntu, xfce" \
      io.openshift.non-scalable=true

# Install language
RUN apt-get update && apt-get install -y \
  locales \
  && locale-gen en_US.UTF-8 \
  && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.UTF-8

# Install timezone
ENV TZ=Asia/Shanghai
RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
  && echo $TZ > /etc/timezone
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get install -y tzdata \
  && dpkg-reconfigure --frontend noninteractive tzdata \
  && apt-get clean &&rm -rf /var/lib/apt/lists/*


# Install ROS
RUN apt-get update && apt-get install -y \
    dirmngr \
    gnupg2 \
    lsb-release \
  && sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list' \
  && apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654 \
  && apt-get update && apt-get install -y \
    ros-melodic-ros-base \
  && apt-get clean &&rm -rf /var/lib/apt/lists/*

# Setup environment
ENV LD_LIBRARY_PATH=/opt/ros/melodic/lib
ENV ROS_DISTRO=melodic
ENV ROS_ROOT=/opt/ros/melodic/share/ros
ENV ROS_PACKAGE_PATH=/opt/ros/melodic/share
ENV ROS_MASTER_URI=http://localhost:11311
ENV ROS_PYTHON_VERSION=
ENV ROS_VERSION=1
ENV PATH=/opt/ros/melodic/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV ROSLISP_PACKAGE_DIRECTORIES=
ENV PYTHONPATH=/opt/ros/melodic/lib/python2.7/dist-packages
ENV PKG_CONFIG_PATH=/opt/ros/melodic/lib/pkgconfig
ENV ROS_ETC_DIR=/opt/ros/melodic/etc/ros
ENV CMAKE_PREFIX_PATH=/opt/ros/melodic
ENV DEBIAN_FRONTEND=

###########################################
# Develop image 
###########################################
FROM base AS dev

ENV DEBIAN_FRONTEND=noninteractive
# ================Install dev tools======================
RUN apt-get update && apt-get install -y \
    python-rosdep \
    python-rosinstall \
    python-rosinstall-generator \
    python-wstool \
    python-vcstools \
    python-pip \
    python-pep8 \
    python-autopep8 \
    pylint \
    build-essential \
    bash-completion \
    git \
    vim \
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  && rosdep init || echo "rosdep already initialized"


ARG USER_NAME
ARG USER_PASSWORD
ARG USER_ID
ARG USER_GID

# Create a non-root user
RUN groupadd --gid $USER_GID $USER_NAME \
  && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USER_NAME \
  # [Optional] Add sudo support for the non-root user
  && apt-get update \
  && apt-get install -y sudo \
  && echo $USER_NAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USER_NAME\
  && chmod 0440 /etc/sudoers.d/$USER_NAME \
  # Cleanup
  && apt-get clean && rm -rf /var/lib/apt/lists/* \
  && echo "source /usr/share/bash-completion/completions/git" >> /home/$USER_NAME/.bashrc \
  && echo "if [ -f /opt/ros/${ROS_DISTRO}/setup.bash ]; then source /opt/ros/${ROS_DISTRO}/setup.bash; fi" >> /home/$USER_NAME/.bashrc
ENV DEBIAN_FRONTEND=

# RUN apt-get update \
#     && apt install sudo \
#     && groupadd --gid $USER_GID $USER_NAME \
#     && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USER_NAME \
#     && usermod -aG sudo $USER_NAME \
#     && yes $USER_PASSWORD | passwd $USER_NAME


###########################################
# Full image 
###########################################
FROM dev AS full

ENV DEBIAN_FRONTEND=noninteractive
# Install the full release
RUN apt-get update && apt-get install -y \
  ros-melodic-desktop \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=

###########################################
#  Full+Gazebo image 
###########################################
FROM full AS gazebo

ENV DEBIAN_FRONTEND=noninteractive
# Install gazebo
RUN apt-get update && apt-get install -y \
  ros-melodic-gazebo* \
  && apt-get clean  &&rm -rf /var/lib/apt/lists/*
ENV DEBIAN_FRONTEND=


###########################################
#  Full+Gazebo+Nvidia image 
###########################################

FROM gazebo AS gazebo-nvidia

################
# Expose the nvidia driver to allow opengl 
# Dependencies for glvnd and X11.
################
RUN apt-get update \
 && apt-get install -y -qq --no-install-recommends \
  libglvnd0 \
  libgl1 \
  libglx0 \
  libegl1 \
  libxext6 \
  libx11-6

# Env vars for the nvidia-container-runtime.
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES graphics,utility,compute
ENV QT_X11_NO_MITSHM 1


###########################################
#  Full+Gazebo+Nvidia image 
###########################################

FROM gazebo AS gazebo-desktop-vnc

ENV DEBIAN_FRONTEND=noninteractive
#  ==============Install some tools
RUN echo "Install some common tools for further installation" \
    && apt-get update \
    && apt-get install -y \
       python-catkin-tools \
       tmux \
       wget \
       gedit \
       net-tools \
       bzip2 \
       unzip \
       openssh-client \
       apt-utils \
       usbutils \
       python-dev\
       ffmpeg \
       python-numpy  #used for websockify/novnc \
    && apt-get clean && rm -rf /var/lib/apt/lists/*


### ================Envrionment config ===============

ENV USER_HOME_DIR=/home/$USER_NAME

## Connection ports for controlling the UI:
# VNC port:5901
# noVNC webport, connect via http://IP:6901/?password=vncpassword
ENV DISPLAY=:1 \
    VNC_PORT=5901 \
    NO_VNC_PORT=6901
EXPOSE $VNC_PORT $NO_VNC_PORT
## environment shell dir
ARG SH_DIR=./xfce_exec 

ENV HOME=$USER_HOME_DIR \
    TERM=xterm \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=$USER_HOME_DIR/install \
    NO_VNC_HOME=$USER_HOME_DIR/noVNC \
    DEBIAN_FRONTEND=noninteractive \
    VNC_COL_DEPTH=24 \
    VNC_RESOLUTION=1280x1024 \
    VNC_PW=vncpassword \
    VNC_VIEW_ONLY=false

WORKDIR $HOME

### ===========Install custom fonts=====================
RUN echo "Installing ttf-wqy-zenhei" \
    && apt-get install -y ttf-wqy-zenhei

### ===========Install xvnc-server & noVNC - HTML5 based VNC viewer============
RUN echo "Install TigerVNC server" \
    && wget -qO- https://dl.bintray.com/tigervnc/stable/tigervnc-1.8.0.x86_64.tar.gz | tar xz --strip 1 -C /

 
RUN echo "Install noVNC - HTML5 based VNC viewer" \
    && mkdir -p $NO_VNC_HOME/utils/websockify \
    && wget -qO- https://github.com/novnc/noVNC/archive/v1.0.0.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME \
    # use older version of websockify to prevent hanging connections on offline containers, see https://github.com/ConSol/docker-headless-vnc-container/issues/50
   && wget -qO- https://github.com/novnc/websockify/archive/v0.6.1.tar.gz | tar xz --strip 1 -C $NO_VNC_HOME/utils/websockify \
   && chmod +x -v $NO_VNC_HOME/utils/*.sh \
   ## create index.html to forward automatically to `vnc_lite.html`
   && ln -s $NO_VNC_HOME/vnc_lite.html $NO_VNC_HOME/index.html



### ================  Install xfce UI  =====================
RUN echo "Install Xfce4 UI components" \
    && apt-get update  \
    && apt-get install -y supervisor xfce4 xfce4-terminal xterm \
    && apt-get purge -y pm-utils xscreensaver* \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

### Add all install scripts for further steps
ADD $SH_DIR/common/install/ $INST_SCRIPTS/
ADD $SH_DIR/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

### Install xfce UI
ADD $SH_DIR/common/xfce/ $HOME/


### ===============  config startup  ======================
RUN echo "Install nss-wrapper to be able to execute image as non-root user" \
    && apt-get update \
    && apt-get install -y libnss-wrapper gettext \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/* \
    && echo "add 'source generate_container_user' to .bashrc" \
    # have to be added to hold all env vars correctly
    &&echo 'source $STARTUPDIR/generate_container_user' >> $HOME/.bashrc

ADD $SH_DIR/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME

### ============Install firefox and chrome browser==================
RUN $INST_SCRIPTS/firefox.sh
RUN $INST_SCRIPTS/chrome.sh

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# bootstrap rosdep
RUN rosdep init && \
  rosdep update --rosdistro $ROS_DISTRO

ENV DEBIAN_FRONTEND=


# # Change USER to 0 to get the root
# USER $USER_NAME

# # setup environment, now in the user mode
# RUN echo "source /opt/ros/melodic/setup.bash" >> $HOME/.bashrc
# # source is the command in /bin/bash, while the default shell is /bin/sh
# RUN /bin/bash -c 'source $HOME/.bashrc'



# ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
# CMD ["--wait"]
