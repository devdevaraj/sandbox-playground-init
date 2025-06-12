#!/bin/bash

# echo "$(cat ./configs/envoy.yaml)" > envoy.yaml
cat <<EOF | sudo tee abcd.service
nameserver 127.0.0.1
nameserver 1.1.1.1
EOF