FROM ubuntu:24.04

ARG BLENDER_VERSION=5.2.2
ARG BLENDER_MAJOR_MINOR=5.2
ARG MCP_VERSION=1.0.3

ENV DEBIAN_FRONTEND=noninteractive
ENV BLENDER_VERSION=${BLENDER_VERSION}
ENV BLENDER_URL=https://download.blender.org/release/Blender5.2/blender-${BLENDER_VERSION}-linux-x64.tar.xz

# 1. Install system runtime graphics stack & dev dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    xz-utils \
    ca-certificates \
    libegl1 \
    libgl1 \
    libgl1-mesa-dri \
    mesa-vulkan-drivers \
    libglu1-mesa \
    libwayland-egl1 \
    libwayland-client0 \
    libwayland-cursor0 \
    libxkbcommon0 \
    libxrender1 \
    libx11-xcb1 \
    libxcb1 \
    libxfixes3 \
    libxi6 \
    libxxf86vm1 \
    libxcursor1 \
    libxinerama1 \
    libxrandr2 \
    libdecor-0-0 \
    libsm6 \
    libice6 \
    libdbus-1-3 \
    libasound2t64 \
    && rm -rf /var/lib/apt/lists/*

# 2. Download and unpack official Blender binaries
RUN mkdir -p /opt/blender && \
    curl -sSL ${BLENDER_URL} | tar -xJ -C /opt/blender --strip-components=1

ENV PATH="/opt/blender:${PATH}"

# 3. Clone and install the latest Blender MCP Add-on into system scripts
RUN mkdir -p /tmp/mcp_addon \
    /opt/blender/${BLENDER_MAJOR_MINOR}/scripts/addons/blender_mcp \
    /opt/blender/${BLENDER_MAJOR_MINOR}/scripts/extensions/user_default/blender_mcp && \
    curl -sSL "https://projects.blender.org/lab/blender_mcp/releases/download/v${MCP_VERSION}/mcp-${MCP_VERSION}.zip?repository=https%3A%2F%2Flab.blender.org%2F&blender_version_min=5.1.0" -o /tmp/mcp_addon/mcp.zip && \
    unzip -q /tmp/mcp_addon/mcp.zip -d /tmp/mcp_addon/extracted && \
    cp -r /tmp/mcp_addon/extracted/. /opt/blender/${BLENDER_MAJOR_MINOR}/scripts/addons/blender_mcp/ && \
    cp -r /tmp/mcp_addon/extracted/. /opt/blender/${BLENDER_MAJOR_MINOR}/scripts/extensions/user_default/blender_mcp/ && \
    rm -rf /tmp/mcp_addon

WORKDIR /workspace

# Default startup sequence: Run hardware diagnostic printout, then launch GUI
CMD ["bash", "-c", "blender --background --python-expr \"import gpu; print('[GPU Audit] Vendor:', gpu.platform.vendor_get(), '| Renderer:', gpu.platform.renderer_get())\" && blender"]
