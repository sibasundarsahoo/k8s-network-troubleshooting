#!/usr/bin/env bash
cd "$(dirname "$0")/.."
E=docs/evidence
mkdir -p $E

echo ">> 00 environment"
{ cilium status; kubectl get nodes -o wide; } > $E/00-environment.txt 2>&1

echo ">> 01 baseline (healthy state)"
{
  echo "## Pods"; kubectl -n demo get pods -o wide
  echo "## Services/Endpoints"; kubectl -n demo get svc,endpoints
  echo "## client -> frontend"; kubectl -n demo exec deploy/client -- curl -s -m 5 http://frontend
  echo "## frontend -> backend"; kubectl -n demo exec deploy/frontend -- curl -s -m 5 http://backend
} > $E/01-baseline.txt 2>&1

echo ">> injecting bug"
kubectl apply -f scenarios/01-networkpolicy-block/break.yaml
sleep 5

echo ">> 02 symptom + diagnose (takes ~70s for the 504)"
{
  echo "## Symptom"
  kubectl -n demo exec deploy/client -- curl -s -m 70 -o /dev/null -w "client->frontend: HTTP %{http_code}\n" http://frontend
  kubectl -n demo exec deploy/frontend -- curl -s -m 5 -o /dev/null -w "frontend->backend: HTTP %{http_code}\n" http://backend
  echo; echo "## Diagnose"
  ./scripts/diagnose.sh
} > $E/02-troubleshooting.txt 2>&1

echo ">> 02b hubble drops (all nodes)"
for _ in 1 2 3; do
  kubectl -n demo exec deploy/frontend -- curl -s -m 3 http://backend >/dev/null 2>&1
done
: > $E/02b-hubble-dropped.txt
for p in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
  echo "=== $p" >> $E/02b-hubble-dropped.txt
  kubectl -n kube-system exec $p -c cilium-agent -- \
    hubble observe --namespace demo --verdict DROPPED --last 10 >> $E/02b-hubble-dropped.txt 2>&1
done

echo ">> applying fix"
./scripts/fix.sh
sleep 5

echo ">> 03 after fix"
{
  ./scripts/verify.sh
  echo "## Hubble after fix"
  for p in $(kubectl -n kube-system get pods -l k8s-app=cilium -o name); do
    echo "=== $p"
    kubectl -n kube-system exec $p -c cilium-agent -- \
      hubble observe --to-pod demo/backend --last 10 2>&1
  done
} > $E/03-after-fix.txt 2>&1

echo "done:"; ls -l $E
