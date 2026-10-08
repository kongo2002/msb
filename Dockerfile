FROM ubuntu:26.04

ARG FLUTTER_VERSION="3.44.8"
ARG JUST_VERSION="1.58.0"
ARG DART_PROTOC_PLUGIN_VERSION="24.0.0"
ARG BUF_VERSION="1.70.0"

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/dotnet:/opt/dotnet/tools:/usr/local/bin:/usr/local/share/pnpm/bin:$PATH" \
    DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    PNPM_HOME=/usr/local/share/pnpm \
    PLAYWRIGHT_BROWSERS_PATH=/opt/playwright

# general dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git unzip xz-utils zip ca-certificates ripgrep less zsh vim iptables libnss3-tools build-essential libicu78

# nodejs
RUN curl -sL https://deb.nodesource.com/setup_25.x -o nodesource_setup.sh \
    && bash nodesource_setup.sh \
    && apt-get install -y --no-install-recommends nodejs \
    && rm nodesource_setup.sh \
    && rm -rf /var/lib/apt/lists/*

# pnpm
RUN mkdir -p "$PNPM_HOME" && chmod 755 "$PNPM_HOME" \
    && curl -fsSL https://get.pnpm.io/install.sh | SHELL=$(which zsh) zsh -

# just
RUN curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | \
    bash -s -- --to /usr/local/bin

# buf
RUN PREFIX="/usr/local" && \
    curl -sSL \
    "https://github.com/bufbuild/buf/releases/download/v${BUF_VERSION}/buf-$(uname -s)-$(uname -m).tar.gz" | \
    tar -xvzf - -C "${PREFIX}" --strip-components 1

# copilot
RUN pnpm add -g @github/copilot

# language servers (used by claude LSP plugins)
RUN pnpm add -g typescript typescript-language-server pyright

# dotnet
RUN curl -sSL https://dot.net/v1/dotnet-install.sh | bash -s -- --channel 10.0 --install-dir /opt/dotnet

# docker
RUN curl -fsSL https://get.docker.com -o get-docker.sh && sh ./get-docker.sh && rm get-docker.sh

# playwright
RUN pnpm add -g @playwright/cli@latest \
    && playwright-cli install-browser chromium --with-deps

# user setup
RUN useradd -m -u 1001 -s /bin/zsh -G docker msb
USER msb
ENV HOME=/home/msb
WORKDIR /home/msb

# flutter
ENV FLUTTER_HOME=/home/msb/flutter
ENV PUB_CACHE=/home/msb/.pub-cache

RUN git clone https://github.com/flutter/flutter.git --branch $FLUTTER_VERSION --depth 1 $FLUTTER_HOME

# claude
RUN curl -fsSL https://claude.ai/install.sh | bash

# rust
ENV CARGO_HOME=/home/msb/.cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | \
    sh -s -- -y --default-toolchain stable --profile minimal

ENV PATH="$PATH:$FLUTTER_HOME/bin:$PUB_CACHE/bin:/home/msb/.local/bin:$CARGO_HOME/bin"

RUN rustup component add rustfmt clippy rust-analyzer

# uv (python)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
 && uv python install 3.14 --default

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

# pre-create directories that may be later bind mounted
RUN mkdir -p /home/msb/.nuget/packages \
    /home/msb/.local/share/pnpm/store \
    /home/msb/.pub-cache/hosted \
    /home/msb/.pub-cache/hosted-hashes \
    /home/msb/.cargo/registry \
    /home/msb/.cargo/git \
    /home/msb/.cache/uv \
    /home/msb/.docker-images

# fzf (the version shipped with ubuntu is _old_)
ADD --chown=msb:msb ./assets/zshrc /home/msb/.zshrc
RUN git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf \
    && ~/.fzf/install --all

ADD --chown=msb:msb ./assets/gitignore_global /home/msb/.gitignore_global
ADD --chown=msb:msb ./assets/claude_settings.json /home/msb/.claude/settings.json
ADD --chown=msb:msb ./assets/claude-statusline.py /home/msb/claude-statusline.py
ADD --chown=msb:msb ./assets/copilot_config.json /home/msb/.copilot/config.json
ADD --chown=msb:msb ./assets/copilot_settings.json /home/msb/.copilot/settings.json

CMD ["/bin/zsh"]
