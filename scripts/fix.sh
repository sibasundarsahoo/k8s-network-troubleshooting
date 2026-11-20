#!/usr/bin/env bash
cd "$(dirname "$0")/.."
kubectl apply -f scenarios/01-networkpolicy-block/fix.yaml
