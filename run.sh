kubectl apply -f postgres.secret.yaml
kubectl apply -f postgres.configmap.yaml
kubectl apply -f redis.configmap.yaml
kubectl apply -f result.configmap.yaml
kubectl apply -f poll.configmap.yaml
kubectl apply -f postgres.volume.yaml
kubectl apply -f redis.deployment.yaml -f redis.service.yaml
kubectl apply -f postgres.deployment.yaml -f postgres.service.yaml
kubectl apply -f worker.deployment.yaml
kubectl apply -f poll.deployment.yaml -f poll.service.yaml
kubectl apply -f result.deployment.yaml -f result.service.yaml
kubectl apply -f traefik.rbac.yaml
kubectl apply -f traefik.deployment.yaml -f traefik.service.yaml
kubectl scale deployment traefik --replicas=1 -n kube-public
kubectl apply -f poll.ingress.yaml -f result.ingress.yaml
kubectl apply -f cadvisor.daemonset.yaml
kubectl wait --for=condition=ready pod -l app=postgres --timeout=60s
echo "CREATE TABLE IF NOT EXISTS votes (id text PRIMARY KEY, vote text NOT NULL);" | \
kubectl exec -i $(kubectl get pod -l app=postgres -o jsonpath='{.items[0].metadata.name}') -c postgres -- psql -U postgres -d voting
echo "$(minikube ip) poll.dop.io result.dop.io" | sudo tee -a /etc/hosts
kubectl port-forward -n kube-public service/traefik-service 30042:8080 &