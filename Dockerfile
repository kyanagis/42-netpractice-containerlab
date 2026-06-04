# 校舎用ラボ環境イメージ: containerlab + sshd + ラボ一式 (base: alpine入りclab)
# 校舎(sudo不要・dockerは使える前提)での使い方:
#   docker run -d --name np --privileged --pid host -p 2222:2222 \
#     -v "$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock" \
#     ghcr.io/kyanagis/42-netpractice-containerlab:latest
#   ssh lab@<host> -p 2222   (pass: lab)   ← VS Code Remote-SSH でも可
#   cd netpractice-containerlab && ./lab.sh solve 00-hello && ./lab.sh down 00-hello
# containerlab: https://containerlab.dev/
FROM ghcr.io/srl-labs/clab:0.75.0

RUN apk add --no-cache sudo shadow openssh libgcc libstdc++ gcompat \
    && useradd -m -s /bin/bash lab \
    && groupadd -f docker \
    && groupadd -f clab_admins \
    && usermod -aG docker,clab_admins lab \
    && echo 'lab:lab' | chpasswd \
    && echo 'lab ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/lab \
    && sed -i 's/^AllowTcpForwarding no/AllowTcpForwarding yes/' /etc/ssh/sshd_config \
    && printf 'Port 2222\nPasswordAuthentication yes\n' >> /etc/ssh/sshd_config

COPY --chown=lab:lab . /home/lab/netpractice-containerlab
RUN mv /usr/bin/containerlab /usr/bin/containerlab.real
COPY bin/np-clab-env.sh /usr/local/lib/np-clab-env.sh
COPY bin/containerlab /usr/bin/containerlab
RUN chmod 755 /usr/bin/containerlab /usr/local/lib/np-clab-env.sh
ENV LAB_RUNTIME=docker
EXPOSE 2222

# 起動時: host鍵生成 → マウントされたdocker.sockをlabが使えるように → sshd
CMD ["sh","-c","ssh-keygen -A >/dev/null 2>&1; [ -S /var/run/docker.sock ] && chmod 666 /var/run/docker.sock 2>/dev/null; exec /usr/sbin/sshd -D -e"]
