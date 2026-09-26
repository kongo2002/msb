FROM ubuntu:24.04

ARG FLUTTER_VERSION="3.44.8"
ARG JUST_VERSION="1.58.0"
ARG DART_PROTOC_PLUGIN_VERSION="24.0.0"
ARG BUF_VERSION="1.70.0"

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/dotnet:/opt/dotnet/tools:/usr/local/bin:$PATH" \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1

# general dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip wget xz-utils zip ca-certificates nodejs npm ripgrep fzf less zsh vim \
    && rm -rf /var/lib/apt/lists/*

# just
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | \
    bash -s -- --to /usr/local/bin

# buf
RUN PREFIX="/usr/local" && \
    curl -sSL \
    "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-$(uname -s)-$(uname -m).tar.gz" | \
    tar -xvzf - -C "${PREFIX}" --strip-components 1

# copilot
RUN npm install -g @github/copilot

# dotnet
RUN curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir /opt/dotnet

# user setup
RUN useradd -m -u 1001 -s /bin/zsh msb
USER msb
ENV HOME=/home/msb
WORKDIR /home/msb

# flutter
ENV FLUTTER_HOME=/home/msb/flutter
ENV PUB_CACHE=/home/msb/.pub-cache

RUN git clone https://github.com/flutter/flutter.git --branch $FLUTTER_VERSION --depth 1 $FLUTTER_HOME

# claude
RUN curl -fsSL https://claude.ai/install.sh | bash

ENV PATH="$PATH:$FLUTTER_HOME/bin:$PUB_CACHE/bin:/home/msb/.local/bin"

RUN flutter config --no-analytics \
 && flutter precache \
 && flutter doctor -v \
 && flutter --version \
 && dotnet --version

RUN git config --global --add safe.directory '*' \
 && git config --global core.excludesfile ~/.gitignore_global \
 && mkdir -p /home/msb/workspace

# dart protoc plugin
RUN dart pub global activate protoc_plugin ${DART_PROTOC_PLUGIN_VERSION}

# azure credentials provider
RUN curl -fsSL https://aka.ms/install-artifacts-credprovider.sh | bash

# claude settings
# - skip onboarding wizard on first run in the sandbox
# - mark workspace folder as trusted
RUN node -e "const fs=require('fs');const p='/home/msb/.claude.json';const c=fs.existsSync(p)?JSON.parse(fs.readFileSync(p,'utf8')):{};c.hasCompletedOnboarding=true;c.projects={'/home/msb/workspace':{hasTrustDialogAccepted:true}};fs.writeFileSync(p,JSON.stringify(c,null,4));"

ADD --chown=msb:msb ./assets/gitignore_global /home/msb/.gitignore_global
ADD --chown=msb:msb ./assets/claude_settings.json /home/msb/.claude/settings.json
ADD --chown=msb:msb ./assets/zshrc /home/msb/.zshrc

CMD ["/bin/zsh"]
