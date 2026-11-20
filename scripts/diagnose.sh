#!/usr/bin/env bash
cd "$(dirname "$0")/.."
echo "== Pods";      kubectl -n demo get pods -o wide
echo "== Service";   kubectl -n demo get svc backend
echo "== Endpoints"; kubectl -n demo get endpoints backend
echo "== DNS";       kubectl -n demo exec deploy/client -- nslookup backend.demo.svc.cluster.local
IP=$(kubectl -n demo get pod -l app=backend -o jsonpath='{.items[0].status.podIP}')
echo "== frontend -> pod IP";  kubectl -n demo exec deploy/frontend -- curl -s -m 5 http://$IP:8080 || echo FAILED
echo "== client -> pod IP";    kubectl -n demo exec deploy/client   -- curl -s -m 5 http://$IP:8080 || echo FAILED
echo "== NetworkPolicy"; kubectl -n demo get networkpolicy; kubectl -n demo describe networkpolicy
