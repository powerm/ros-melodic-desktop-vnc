# This Dockerfile is used to build an headles vnc image based on Ubuntu

FROM ubuntu:18.04

ENV REFRESHED_AT 2021-01-28

LABEL io.k8s.description="Headless VNC Container with Xfce window manager, firefox and chromium" \
      io.k8s.display-name="Headless VNC Container based on Ubuntu" \
      io.openshift.expose-services="6901:http,5901:xvnc" \
      io.openshift.tags="vnc, ubuntu, xfce" \
      io.openshift.non-scalable=true

ARG USER_NAME
ARG USER_PASSWORD
ARG USER_ID
ARG USER_GID

RUN apt-get update
RUN apt install sudo 
RUN useradd -ms /bin/bash $USER_NAME
RUN usermod -aG sudo $USER_NAME
RUN yes $USER_PASSWORD | passwd $USER_NAME

# set uid and gid to match those outside the container
RUN usermod -u $USER_ID $USER_NAME
RUN groupmod -g $USER_GID $USER_NAME

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

### Envrionment config
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

### Add all install scripts for further steps
ADD $SH_DIR/common/install/ $INST_SCRIPTS/
ADD $SH_DIR/ubuntu/install/ $INST_SCRIPTS/
RUN find $INST_SCRIPTS -name '*.sh' -exec chmod a+x {} +

### Install some common tools
RUN $INST_SCRIPTS/tools.sh
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

### Install custom fonts
RUN $INST_SCRIPTS/install_custom_fonts.sh

### Install xvnc-server & noVNC - HTML5 based VNC viewer
RUN $INST_SCRIPTS/tigervnc.sh
RUN $INST_SCRIPTS/no_vnc.sh

### Install firefox and chrome browser
RUN $INST_SCRIPTS/firefox.sh
RUN $INST_SCRIPTS/chrome.sh

### Install xfce UI
RUN $INST_SCRIPTS/xfce_ui.sh
ADD $SH_DIR/common/xfce/ $HOME/

### configure startup
RUN $INST_SCRIPTS/libnss_wrapper.sh
ADD $SH_DIR/common/scripts $STARTUPDIR
RUN $INST_SCRIPTS/set_user_permission.sh $STARTUPDIR $HOME


### ======install ros==========
# install ros(from https://github.com/osrf/docker_images/blob/b075c7dbe56055d862f331f19e1e74ba653e181a/ros/melodic/ubuntu/bionic/ros-core/Dockerfile)
# install packages
RUN apt-get update && apt-get install -q -y \
    dirmngr \
    gnupg2 \
    && rm -rf /var/lib/apt/lists/*


# setup sources.list
RUN echo "deb http://packages.ros.org/ros/ubuntu bionic main" > /etc/apt/sources.list.d/ros1-latest.list

# setup keys
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

# install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    python-rosdep \
    python-rosinstall \
    python-vcstools \
    && rm -rf /var/lib/apt/lists/*

# setup environment
ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

ENV ROS_DISTRO melodic
# bootstrap rosdep
RUN rosdep init && \
  rosdep update --rosdistro $ROS_DISTRO

# install ros packages
RUN apt-get update && apt-get install -y \
    # ros-melodic-ros-core=1.4.1-0* \
    ros-melodic-desktop-full \
    && rm -rf /var/lib/apt/lists/*

# install catkin
RUN apt-get update && apt-get install -y \
  python-catkin-tools \
  && rm -rf /var/lib/apt/lists/* 

# =========================
# user tools， -y means type yes when interactive 
RUN apt-get update && apt-get install -y \
  vim \
  git \
  && rm -rf /var/lib/apt/lists/*


# Change USER to 0 to get the root
USER $USER_NAME

# setup environment, now in the user mode
RUN echo "source /opt/ros/melodic/setup.bash" >> $HOME/.bashrc
# source is the command in /bin/bash, while the default shell is /bin/sh
RUN /bin/bash -c 'source $HOME/.bashrc'


ENTRYPOINT ["/dockerstartup/vnc_startup.sh"]
CMD ["--wait"]
