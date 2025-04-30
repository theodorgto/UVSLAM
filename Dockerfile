# FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0  # Keep this commented if you are not on Jetson
FROM nvcr.io/nvidia/cuda:12.5.0-devel-ubuntu22.04

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
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    # Clean up apt cache
    rm -rf /var/lib/apt/lists/*

# Install development tools and libraries
# Git is installed here
RUN apt-get update && apt-get install -y \
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
    libeigen3-dev && \
    # Clean up apt cache
    rm -rf /var/lib/apt/lists/*

# 1. Install ROS 2 Humble
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS 2 core and GUI tools like rqt_graph
# This implicitly installs Python 3 dependencies
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
    python3-rosdep && \
    # Clean up apt cache
    rm -rf /var/lib/apt/lists/*

# Note: The second block installing ROS packages seemed redundant with the first, removed it.

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
    make -j$(nproc) && make install && \
    cd / && rm -rf gtsam # Clean up source code after install

# Clone and build Iridescence (optional but recommended)
RUN git clone https://github.com/koide3/iridescence --recursive && \
    mkdir iridescence/build && cd iridescence/build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install && \
    cd / && rm -rf iridescence # Clean up source code after install

# Clone and build gtsam_points with CUDA
RUN git clone https://github.com/koide3/gtsam_points && \
    mkdir gtsam_points/build && cd gtsam_points/build && \
    cmake .. -DBUILD_WITH_CUDA=ON && \
    make -j$(nproc) && make install && \
    cd / && rm -rf gtsam_points # Clean up source code after install

# Prepare ROS 2 workspace and clone GLIM packages
RUN mkdir -p ${ROS_WORKSPACE}/src && cd ${ROS_WORKSPACE}/src && \
    git clone https://github.com/koide3/glim && \
    git clone https://github.com/koide3/glim_ros2

# Build ROS 2 workspace
RUN bash -c ". /opt/ros/${ROS_DISTRO}/setup.sh && \
    cd ${ROS_WORKSPACE} && \
    colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release"
# Note: Leaving the build directory, colcon cleans up intermediate files but not the build folder itself. Consider adding 'rm -rf ${ROS_WORKSPACE}/build ${ROS_WORKSPACE}/install ${ROS_WORKSPACE}/log' if image size is critical and you only need the built executables/libraries available via sourcing setup.bash

# --- ADDED SECTION: Install Miniconda ---
# Install Miniconda to /opt/conda
# Use uname -m or dpkg --print-architecture to determine architecture and download the correct installer
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "amd64" ]; then \
        CONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"; \
    elif [ "$ARCH" = "arm64" ]; then \
        CONDA_URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh"; \
    else \
        echo "Unsupported architecture: $ARCH"; \
        exit 1; \
    fi && \
    echo "Downloading Miniconda for $ARCH from $CONDA_URL" && \
    curl -fsSL -o ~/miniconda.sh "$CONDA_URL" && \
    bash ~/miniconda.sh -b -p /opt/conda && \
    rm ~/miniconda.sh && \
    # Make conda command available system-wide
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    # Clean up conda package cache to reduce image size
    /opt/conda/bin/conda clean -afy && \
    # Verify install (optional)
    /opt/conda/bin/conda --version

# Add Conda bin directory to the system PATH
ENV PATH=/opt/conda/bin:$PATH

# --- ADDED SECTION: Add ROS Aliases ---
# Add aliases for sourcing ROS setup files to /root/.bashrc
RUN echo -e "\n# Custom ROS Aliases added by Dockerfile" >> /root/.bashrc && \
    echo "alias sr1='source /opt/ros/${ROS_DISTRO}/setup.bash'" >> /root/.bashrc && \
    echo "alias sws='source ${ROS_WORKSPACE}/install/setup.bash'" >> /root/.bashrc && \
    echo "alias source_ros1='source /opt/ros/${ROS_DISTRO}/setup.bash'" >> /root/.bashrc && \
    echo "alias source_ws='source ${ROS_WORKSPACE}/install/setup.bash'" >> /root/.bashrc
# --- END ADDED SECTION ---

# Finalize
RUN ldconfig

# Entrypoint setup
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]