#!/bin/sh

ns=${1:-default}

kubectl create secret tls ca-key-pair \
   --cert=ca.crt \
   --key=ca.key \
   --namespace=$ns