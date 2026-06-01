# 校舎用ラボ環境イメージ: containerlab + sshd + ラボ一式 (base: alpine入りclab)
# 校舎(sudo不要・dockerは使える前提)での使い方:
#   docker run -d --privileged --network host --pid host \
#     -v /var/run/docker.sock:/var/run/docker.sock \
#     ghcr.io/kyanagis/42-netpractice-containerlab:latest
#   ssh lab@<host> -p 2222   (pass: lab)   ← VS Code Remote-SSH でも可
#   cd netpractice-containerlab && ./lab.sh test 00-hello   (LAB_RUNTIME=linux 既定)
# containerlab: https://containerlab.dev/
FROM ghcr.io/srl-labs/clab:0.75.0

RUN apk add --no-cache sudo shadow openssh \
    && useradd -m -s /bin/bash lab \
    && echo 'lab:lab' | chpasswd \
    && echo 'lab ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/lab \
    && printf 'Port 2222\nPasswordAuthentication yes\n' >> /etc/ssh/sshd_config

COPY --chown=lab:lab . /home/lab/netpractice-containerlab
ENV LAB_RUNTIME=linux
EXPOSE 2222

# 起動時: host鍵生成 → マウントされたdocker.sockをlabが使えるように → sshd
CMD ["sh","-c","ssh-keygen -A >/dev/null 2>&1; [ -S /var/run/docker.sock ] && chmod 666 /var/run/docker.sock 2>/dev/null; exec /usr/sbin/sshd -D -e"]
