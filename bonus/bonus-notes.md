### Recuperer le password gitlab:
```sh
kubectl exec -n gitlab deploy/gitlab -- cat /etc/gitlab/initial_root_password
```
