#!/usr/bin/env bash
cd "$(dirname "$0")/.."
kubectl -n demo exec deploy/frontend -- curl -s -m 5 http://backend
kubectl -n demo exec deploy/client   -- curl -s -m 5 http://frontend
kubectl -n demo run intruder --image=curlimages/curl:8.10.1 --restart=Never --command -- sleep 300
kubectl -n demo wait --for=condition=Ready pod/intruder --timeout=60s
kubectl -n demo exec intruder -- curl -s -m 5 http://backend || echo "BLOCKED (expected)"
kubectl -n demo delete pod intruder
