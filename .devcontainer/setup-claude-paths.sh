#!/bin/bash
set -e

# ホストの ~/.claude パスがコンテナ内で解決できるようシンボリックリンクを作成
# ホームが一致していれば何もしない（CI環境等）
[ "$HOST_HOME" = "$HOME" ] && exit 0
[ -z "$HOST_HOME" ] && exit 0

HOST_HOME_PARENT=$(dirname "$HOST_HOME")
sudo mkdir -p "$HOST_HOME_PARENT"
sudo ln -sfn "$HOME" "$HOST_HOME"

echo "Symlinked $HOST_HOME -> $HOME"
