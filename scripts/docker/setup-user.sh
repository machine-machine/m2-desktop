#!/bin/bash
# =============================================================================
# M2 Desktop - User Setup
# Creates the 'developer' user with UID/GID 1000
# =============================================================================
set -e

USER_NAME="${M2_USER:-developer}"
USER_UID="${M2_UID:-1000}"
USER_GID="${M2_GID:-1000}"

echo "=== Creating user: ${USER_NAME} (${USER_UID}:${USER_GID}) ==="

# Create group if it doesn't exist
groupadd -g ${USER_GID} ${USER_NAME} 2>/dev/null || true

# Create user if it doesn't exist
useradd -m -s /bin/bash -u ${USER_UID} -g ${USER_GID} ${USER_NAME} 2>/dev/null || true

# Grant sudo access without password
echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME}
chmod 0440 /etc/sudoers.d/${USER_NAME}

# Create standard directories
mkdir -p /home/${USER_NAME}/.config
mkdir -p /home/${USER_NAME}/.local/share
mkdir -p /home/${USER_NAME}/Desktop
chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

echo "=== User ${USER_NAME} created ==="
