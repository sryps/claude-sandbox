# Use official Go image as base
FROM debian:trixie-slim

RUN mkdir /workspace

# Install dependencies
RUN apt-get update && apt-get install -y \
	curl \
	git \
	build-essential \
	ca-certificates \
	tree \
	jq \
	python3 \
	python3-pip \
	python3-venv \
	openssl \
	protobuf-compiler \
	libclang-dev \
	clang \
	llvm \
	pkg-config \
	libssl-dev \
	net-tools \
	wget \
	dnsutils \
	ansible \
	gnupg \
	lsb-release \
	gh \
	&& rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian trixie stable" > /etc/apt/sources.list.d/docker.list && \
	apt-get update && apt-get install -y docker-ce-cli && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
	echo "deb [arch=amd64 signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" > /etc/apt/sources.list.d/hashicorp.list && \
	apt-get update && apt-get install -y terraform && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for Claude Code)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
	&& apt-get install -y nodejs \
	&& rm -rf /var/lib/apt/lists/*

# Install Claude Code, TypeScript, and Quint CLI
RUN npm install -g @anthropic-ai/claude-code typescript @informalsystems/quint

# Install Go
RUN curl -OL https://go.dev/dl/go1.24.1.linux-amd64.tar.gz && \
	tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz && \
	rm go1.24.1.linux-amd64.tar.gz

# Create a non-root user for security
RUN useradd -m -s /bin/bash dev && \
	chown -R dev:dev /workspace

# Set up working directory
WORKDIR /workspace

RUN mkdir -p /run/secrets && chown dev:dev /run/secrets

# Switch to non-root user
USER dev

# Install Rust for the dev user (after switching to dev user)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Set environment variables
ENV GOPATH=/home/dev/go
ENV PATH=/usr/local/go/bin:$GOPATH/bin:/home/dev/.cargo/bin:$PATH

RUN cargo install taplo-cli

# Default command
CMD ["/bin/bash"]
