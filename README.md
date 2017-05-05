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

upgrade image

```
helm upgrade --set=elasticsearch.image.repository=docker.io/elasticsearch,elasticsearch.image.tag=2.3.4 [release_name]
```
