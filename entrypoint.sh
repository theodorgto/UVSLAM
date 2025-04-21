#!/bin/bash
set -e

# Source ROS distribution
source "/opt/ros/${ROS_DISTRO}/setup.bash"

# Source workspace if exists
if [ -f "${ROS_WORKSPACE}/install/setup.bash" ]; then
    source "${ROS_WORKSPACE}/install/setup.bash"
fi

# Execute command
exec "$@"