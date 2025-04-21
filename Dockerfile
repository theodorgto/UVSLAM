FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

# Set up locale and environment
ENV LANG=en_US.UTF-8
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8


# # Install core dependencies
RUN apt-get update && apt-get install -y \
    curl \
    software-properties-common \
    build-essential \
    cmake \
    git \
    gpg


RUN apt update && apt install -y \
    libomp-dev libboost-all-dev libmetis-dev \
    libfmt-dev libspdlog-dev \
    libglm-dev libglfw3-dev libpng-dev libjpeg-dev

RUN apt install -y libeigen3-dev

RUN git clone https://github.com/borglab/gtsam && \
    cd gtsam && \
    git checkout 4.2a9 && \
    mkdir build && \
    cd build && \
    cmake .. \
        -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
        -DGTSAM_BUILD_TESTS=OFF \
        -DGTSAM_WITH_TBB=OFF \
        -DGTSAM_USE_SYSTEM_EIGEN=ON \
        -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF && \
    make -j$(nproc) && \
    make install

# Install Iridescence for visualization
# This is optional but highly recommended
RUN git clone https://github.com/koide3/iridescence --recursive && \
    mkdir iridescence/build && cd iridescence/build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && \
    make install

# Install gtsam_points
RUN git clone https://github.com/koide3/gtsam_points && \
    mkdir gtsam_points/build && cd gtsam_points/build && \
    cmake .. -DBUILD_WITH_CUDA=ON && \
    make -j$(nproc) && \
    make install 

# Make shared libraries visible to the system
RUN ldconfig

# install FLIM for ROS2
RUN mkdir -p ~/ros2_ws/src

RUN cd ~/ros2_ws/src && \
    git clone https://github.com/koide3/glim && \
    git clone https://github.com/koide3/glim_ros2

# RUN export DEBIAN_FRONTEND=noninteractive
ARG DEBIAN_FRONTEND=noninteractive
RUN sh -c 'echo "deb [arch=amd64,arm64] http://repo.ros2.org/ubuntu/main `lsb_release -cs` main" > /etc/apt/sources.list.d/ros2-latest.list'
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -

RUN apt update && apt install -y python3-colcon-common-extensions

# Set ROS 2 distribution
ENV ROS_DISTRO=humble
ENV ROS_WORKSPACE=/root/ros2_ws

# 1. Install ROS 2 Humble
RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    lsb-release \
    software-properties-common && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS 2 core packages
RUN apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-ros-base \
    python3-colcon-common-extensions \
    python3-rosdep \
    ros-${ROS_DISTRO}-ament-cmake-auto \
    ros-${ROS_DISTRO}-rclcpp \
    ros-${ROS_DISTRO}-std-msgs

# # Initialize rosdep and install dependencies
# RUN apt-get update && apt-get install -y \
#     libiridescence \
#     python3-rosdep

# RUN rosdep init && \
#     rosdep update && \
#     rosdep install --from-paths ${ROS_WORKSPACE}/src --ignore-src -y --rosdistro ${ROS_DISTRO}

RUN apt update
RUN apt install -y \ 
    ros-humble-image-transport \
    ros-humble-cv-bridge


RUN . /opt/ros/${ROS_DISTRO}/setup.sh && \
    cd ~/ros2_ws && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release


# Final configuration
RUN ldconfig

# Setup entrypoint
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]