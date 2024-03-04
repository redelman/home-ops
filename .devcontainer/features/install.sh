#!/usr/bin/env bash
set -e
set -o noglob

apk add --no-cache \
    bash bash-completion bind-tools ca-certificates curl python3 \
    py3-pip moreutils jq git iputils openssh-client openssh-sk-helper

apk add --no-cache \
    --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
        age helm kubectl sops ansible opentofu minio-client

for app in \
    "budimanjojo/talhelper!" \
    "cilium/cilium-cli!!?as=cilium&type=script" \
    "cli/cli!!?as=gh&type=script" \
    "cloudflare/cf-terraforming!!?as=cf-terraforming&type=script" \
    "cloudflare/cloudflared!!?as=cloudflared&type=script" \
    "derailed/k9s!!?as=k9s&type=script" \
    "direnv/direnv!!?as=direnv&type=script" \
    "fluxcd/flux2!!?as=flux&type=script" \
    "go-task/task!!?as=task&type=script" \
    "helmfile/helmfile!!?as=helmfile&type=script" \
    "kubecolor/kubecolor!!?as=kubecolor&type=script" \
    "kubernetes-sigs/krew!!?as=krew&type=script" \
    "kubernetes-sigs/kustomize!!?as=kustomize&type=script" \
    "stern/stern!!?as=stern&type=script" \
    "siderolabs/talos!!?as=talosctl&type=script" \
    "yannh/kubeconform!!?as=kubeconform&type=script" \
    "mikefarah/yq!!?as=yq&type=script"
do
    echo "=== Installing ${app} ==="
    curl -fsSL "https://i.jpillora.com/${app}" | bash
done

# Setup autocompletions for bash
for tool in cilium flux helm helmfile k9s kubectl kustomize talhelper talosctl; do
   $tool completion bash >> /home/vscode/.bash_completion
done

gh completion --shell bash >> /home/vscode/.bash_completion
stern --completion bash >> /home/vscode/.bash_completion
yq shell-completion bash >> /home/vscode/.bash_completion

# Hooks
direnv hook bash >> /home/vscode/.bashrc

# Add aliases into bash
tee -a /home/vscode/.bashrc > /dev/null <<EOF

# Aliases
alias kubectl=kubecolor
alias k=kubectl
alias terraform=tofu
alias tf=tofu
EOF

# SOPS support
mkdir -p /home/vscode/.config/direnv/lib /home/vscode/.config/sops/age
tee /home/vscode/.config/direnv/lib/use_sops.sh > /dev/null <<EOF

use_sops() {
    local path=\${1:-\$PWD/secrets.sops.yaml}
    if [ -e "\$path" ]
    then
        if grep -q -E '^sops:' "\$path"
        then
            eval "\$(sops --decrypt --output-type dotenv "\$path" 2>/dev/null | direnv dotenv bash /dev/stdin || false)"
        else
            if [ -n "\$(command -v yq)" ]
            then
                eval "\$(yq eval --output-format props "\$path" | direnv dotenv bash /dev/stdin)"
                export SOPS_WARNING="unencrypted \$path"
            fi
        fi
    fi
    watch_file "\$path"
}
EOF

tee /home/vscode/.config/direnv/direnvrc > /dev/null <<EOF
#!/bin/sh

if [ -f ".env" ]; then
        dotenv
fi

use sops
EOF

# Configure krew. Sudo is needed because otherwise krew is set up for the root user
sudo -u vscode krew install krew
tee -a /home/vscode/.bashrc > /dev/null <<EOF
# Add krew to path
export PATH="\${KREW_ROOT:-\$HOME/.krew}/bin:\$PATH"
EOF

# Install krew plugins
for plugin in "cilium node-shell oidc-login"; do
  sudo -u vscode krew install $plugin
done

# Add direnv whitelist for the workspace directory
mkdir -p /home/vscode/.config/direnv
tee /home/vscode/.config/direnv/direnv.toml > /dev/null <<EOF
[whitelist]
prefix = [ "/workspaces" ]
EOF

# Set ownership vscode .config directory to the vscode user
chown -R vscode:vscode /home/vscode/.config