# inu-es-env

install with helm

```
helm repo add grandsys https://grandsys.github.io/helm-repository
helm install --set=elasticsearch.service.name=es grandsys/inu-es-env
```
purge

```
helm ls
helm del --purge [release_name]
kubectl delete pvc storage-es-data-{0,1}
```
