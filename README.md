# 42-netpractice-containerlab

## 起動（校舎/rootless Docker）

```bash
docker rm -f np 2>/dev/null || true
docker volume create np-repo >/dev/null
docker run -d --name np --privileged --pid host \
  -p 2222:2222 \
  -e LAB_RUNTIME=docker \
  -e CLAB_WORKSPACE_VOLUME=np-repo \
  -e DOCKER_SOCKET_HOST="$XDG_RUNTIME_DIR/docker.sock" \
  -v "$XDG_RUNTIME_DIR/docker.sock:/var/run/docker.sock" \
  -v np-repo:/home/lab/netpractice-containerlab \
  ghcr.io/kyanagis/42-netpractice-containerlab:latest

ssh lab@localhost -p 2222   # pass: lab
cd netpractice-containerlab
./lab.sh up 00-hello && ./lab.sh test 00-hello && ./lab.sh down 00-hello
```

VS Code は Remote-SSH で `np-lab` に接続し、Remote 側へ `srl-labs.vscode-containerlab` を入れる。

VS Code が server download を繰り返す場合は接続先を掃除:

```bash
ssh lab@localhost -p 2222 'rm -rf ~/.vscode-server ~/.vscode-server-insiders'
```

`2222` が rootlesskit に掴まったままなら Docker を再起動:

```bash
systemctl --user restart docker
```

```bash
# np コンテナ内では LAB_RUNTIME=docker のまま使う
./lab.sh ls
./lab.sh up    level10
./lab.sh test  level10
./lab.sh shell level10 h1
./lab.sh graph level10
./lab.sh down  level10
./lab.sh test-all                # 全ラボを up->test->down
```

~/.ssh/config
```
  Host np-lab
      HostName localhost
      Port 2222
      User lab
      IdentityFile ~/.ssh/id_ed25519
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
```
