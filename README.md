# inu-es-env
for local test
```
docker run -p 9200:9200 -e "xpack.security.enabled=false" -e "http.host=0.0.0.0" -e "transport.host=127.0.0.1" docker.elastic.co/elasticsearch/elasticsearch:5.3.0
```