kubectl delete ingress poll-ingress result-ingress
kubectl delete deployment traefik -n kube-public
kubectl delete service traefik-service -n kube-public
kubectl delete deployment poll result worker postgres redis
kubectl delete service poll-service result-service postgres-service redis-service
kubectl delete pvc postgres-pvc
kubectl delete pv postgres-pv
kubectl delete configmap postgres-config redis-config result-config poll-config
kubectl delete secret postgres-secret
kubectl delete clusterrolebinding traefik-ingress-controller
kubectl delete clusterrole traefik-ingress-controller
kubectl delete serviceaccount traefik-ingress-controller -n kube-public
kubectl delete daemonset cadvisor -n kube-system