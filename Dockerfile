FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

# Set environment and locale
ENV LANG=en_US.UTF-8 \
    ROS_DISTRO=humble \
    ROS_WORKSPACE=/root/ros2_ws \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    locales \
    curl \
    gnupg \
    lsb-release \
    software-properties-common && \
    locale-gen en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# Install development tools and libraries
RUN apt-get install -y \
    build-essential \
    cmake \
    git \
    gpg \
    libomp-dev \
    libboost-all-dev \
    libmetis-dev \
    libfmt-dev \
    libspdlog-dev \
    libglm-dev \
    libglfw3-dev \
    libpng-dev \
    libjpeg-dev \
    libeigen3-dev

# 1. Install ROS 2 Humble
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS 2 core and GUI tools like rqt_graph
RUN apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-ros-base \
    ros-${ROS_DISTRO}-ament-cmake-auto \
    ros-${ROS_DISTRO}-rclcpp \
    ros-${ROS_DISTRO}-std-msgs \
    ros-humble-image-transport \
    ros-humble-cv-bridge \
    ros-humble-rqt-graph \
    ros-humble-rqt-common-plugins \
    python3-colcon-common-extensions \
    python3-rosdep

    RUN apt-get update && apt-get install -y \
    ros-${ROS_DISTRO}-ros-base \
    python3-colcon-common-extensions \
    python3-rosdep \
    ros-${ROS_DISTRO}-ament-cmake-auto \
    ros-${ROS_DISTRO}-rclcpp \
    ros-${ROS_DISTRO}-std-msgs

# Clone and build GTSAM
RUN git clone https://github.com/borglab/gtsam && \
    cd gtsam && git checkout 4.2a9 && \
    mkdir build && cd build && \
    cmake .. \
        -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
        -DGTSAM_BUILD_TESTS=OFF \
        -DGTSAM_WITH_TBB=OFF \
        -DGTSAM_USE_SYSTEM_EIGEN=ON \
        -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF && \
    make -j$(nproc) && make install

# Clone and build Iridescence (optional but recommended)
RUN git clone https://github.com/koide3/iridescence --recursive && \
    mkdir iridescence/build && cd iridescence/build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install

# Clone and build gtsam_points with CUDA
RUN git clone https://github.com/koide3/gtsam_points && \
    mkdir gtsam_points/build && cd gtsam_points/build && \
    cmake .. -DBUILD_WITH_CUDA=ON && \
    make -j$(nproc) && make install

# Prepare ROS 2 workspace and clone GLIM packages
RUN mkdir -p ${ROS_WORKSPACE}/src && cd ${ROS_WORKSPACE}/src && \
    git clone https://github.com/koide3/glim && \
    git clone https://github.com/koide3/glim_ros2

# Build ROS 2 workspace
RUN bash -c ". /opt/ros/${ROS_DISTRO}/setup.sh && \
    cd ${ROS_WORKSPACE} && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release"

# Finalize
RUN ldconfig

# Entrypoint setup
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
