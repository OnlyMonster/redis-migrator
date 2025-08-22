FROM redis:7-alpine

# Install Python and dependencies
RUN apk add --no-cache \
  python3 \
  py3-pip \
  py3-redis \
  bash

# Set up working directory
WORKDIR /app

# Install Python packages
COPY requirements.txt /app/
RUN pip3 install --break-system-packages -r requirements.txt

# Ensure scripts directory exists and is executable
RUN mkdir -p /app/scripts && chmod 755 /app/scripts

# Set shell to bash
SHELL ["/bin/bash", "-c"]

# Set default command
CMD ["/bin/bash"]