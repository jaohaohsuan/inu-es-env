FROM alpine:edge

RUN apk --no-cache add ansible bash vim
ADD hosts /etc/ansible/hosts
WORKDIR /opt/ansible
ADD files ./files
ADD templates ./templates
ADD *.yaml ./

ENV ELASTICSEARCH_ADDR=127.0.0.1
ENV ELASTICSEARCH_PORT=9200
ENV TERM=xterm

CMD [ "ansible-playbook", "entrypoint.yaml" ]