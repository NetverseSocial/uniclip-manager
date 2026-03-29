FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    openssh-server \
    xclip \
    xvfb \
    tmux \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uniclip
RUN curl -fsSL "https://github.com/quackduck/uniclip/releases/latest/download/uniclip_2.3.6_Linux_arm64.tar.gz" \
    -o /tmp/uniclip.tar.gz && tar xzf /tmp/uniclip.tar.gz -C /usr/local/bin uniclip && \
    chmod +x /usr/local/bin/uniclip && rm /tmp/uniclip.tar.gz

# Set up SSH
RUN mkdir /run/sshd && \
    echo 'root:uniclip' | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]
