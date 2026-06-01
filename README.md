# 42-netpractice-containerlab

```bash
docker run -d --name np --privileged --network host --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/kyanagis/42-netpractice-containerlab:latest
# VS Code Remote-SSH:  ssh lab@<host> -p 2222   (pass: lab)
#   → 拡張 srl-labs.vscode-containerlab でGUI(TopoViewer/Deploy)
cd netpractice-containerlab
./lab.sh up 00-hello && ./lab.sh test 00-hello && ./lab.sh down 00-hello
```

```bash
export LAB_RUNTIME=docker        # Linuxにclab導入済みなら linux
./lab.sh ls
./lab.sh up    level10
./lab.sh test  level10
./lab.sh shell level10 h1
./lab.sh graph level10
./lab.sh down  level10
./lab.sh test-all                # 全ラボを up->test->down
```
