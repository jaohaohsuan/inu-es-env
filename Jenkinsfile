def podLabel = "${env.JOB_NAME}-${env.BUILD_NUMBER}".replace('/', '-').replace('.', '')
def esImageName = 'docker.elastic.co/elasticsearch/elasticsearch:5.3.0'
podTemplate(
    label: podLabel,
    containers: [
        containerTemplate(name: 'jnlp', image: env.JNLP_SLAVE_IMAGE, args: '${computer.jnlpmac} ${computer.name}', alwaysPullImage: true),
        containerTemplate(name: 'kube', image: "${env.PRIVATE_REGISTRY}/library/kubectl:v1.7.2", ttyEnabled: true, command: 'cat'),
        containerTemplate(name: 'helm', image: env.HELM_IMAGE, ttyEnabled: true, command: 'cat'),
        containerTemplate(name: 'dind', image: 'docker:stable-dind', privileged: true, ttyEnabled: true, command: 'dockerd', args: '--host=unix:///var/run/docker.sock --host=tcp://0.0.0.0:2375 --storage-driver=vfs')
  ],
    volumes: [
        emptyDirVolume(mountPath: '/var/run', memory: false),
        hostPathVolume(mountPath: "/etc/docker/certs.d/${env.PRIVATE_REGISTRY}/ca.crt", hostPath: "/etc/docker/certs.d/${env.PRIVATE_REGISTRY}/ca.crt"),
        hostPathVolume(mountPath: '/home/jenkins/.kube/config', hostPath: '/etc/kubernetes/admin.conf'),
        persistentVolumeClaim(claimName: env.HELM_REPOSITORY, mountPath: '/var/helm/', readOnly: false)
    ]) {

    node(podLabel) {
        ansiColor('xterm') {
            def last_commit = sh(script: 'git log --format=%B -n 1', returnStdout: true).trim()
            def esContaienr
            def stopElasticsearch = { }
            try {
                
                stage('run elasticsearch') {
                    checkout scm

                    if (params.ELASTICSEARCH_ADDR && params.ELASTICSEARCH_PORT) {   
                        echo 'skipped'
                        setElasticsearchEndPoint(params.ELASTICSEARCH_ADDR, params.ELASTICSEARCH_PORT)
                    }
                    else {
                        esContaienr = docker.image(esImageName).run('--network=host --privileged -e ES_JAVA_OPTS="-Xms128m -Xmx128m"')
                        stopElasticsearch = { esContaienr.stop() }
                        setElasticsearchEndPoint("127.0.0.1", 9200)
                    }

                    timeout(time: 60, unit: 'SECONDS') {
                        waitUntil {
                            def r = sh script: 'curl -XGET http://$ELASTICSEARCH_ADDR:$ELASTICSEARCH_PORT?pretty', returnStatus: true
                            return (r == 0)
                        }
                    }
                }
                
                stage('setup') {
                    
                    parallel IndexTemplate: {
                        ansiblePlaybook colorized: true, playbook: 'logs-index-template.yaml', inventory: 'hosts', extras: ''
                    }, StoredQuery: {
                        ansiblePlaybook colorized: true, playbook: 'stored-query-config.yaml', inventory: 'hosts', extras: ''
                    },
                    failFast: false
                }

                stage('run test') {
                    
                    if(params.WITHOUT_FAKEDATA) {
                        echo 'creating fake data skipped'
                    }
                    else {
                        ansiblePlaybook colorized: true, playbook: 'sample-data.yaml', inventory: 'hosts', extras: ''
                    }
                }

                def image
                stage('build image') {
                    image = docker.build("${env.PRIVATE_REGISTRY}/inu/inuesenv", '.')
                }

                stage('test image') {
                    image.inside {
                        sh '''
                        ansible --version
                        python --version
                        ansible-playbook entrypoint.yaml
                        '''
                    }
                }
                
                stage('push image') {
                    withDockerRegistry(url: env.PRIVATE_REGISTRY_URL, credentialsId: 'docker-login') {
                        image.push(env.BRANCH_NAME)
                    }
                }

                container('helm') {
                    sh 'helm init --client-only'
                    sh "helm repo add grandsys ${env.HELM_PUBLIC_REPO_URL}"
                    sh 'helm repo update'

                    def releaseName = podLabel

                    try {
                        dir('inu-es-env') {
                            stage('test chart') {
                                echo 'substitute image BUILD_TAG'
                                sh """
                                sed -i \'s/\${BUILD_TAG}/${env.BRANCH_NAME}/\' ./values.yaml
                                """
                                sh 'helm dep up .'
                                sh 'helm lint .'
                                def service = podLabel
                                sh "helm install --set=elasticsearch.service.name=${service},replicaCount.data=1 -n ${releaseName} ."
                                sh "helm test ${releaseName} --cleanup"
                            }
                        }

                        stage('package chart') {
                            dir('inu-es-env') {
                                echo 'archive chart'
                                sh 'helm package --destination /var/helm/repo .'
                                
                                echo 'generate an index file'
                                sh """
                                merge=`[[ -e '/var/helm/repo/index.yaml' ]] && echo '--merge /var/helm/repo/index.yaml' || echo ''`
                                helm repo index --url ${env.HELM_PUBLIC_REPO_URL} \$merge /var/helm/repo
                                """
                            }
                            build job: 'helm-repository/master', parameters: [string(name: 'commiter', value: "${env.JOB_NAME}\ncommit: ${last_commit}")]
                        }

                    } catch (error) {
                        echo "${e}"
                        currentBuild.result = FAILURE
                    } finally {
                        stage('clean up') {
                            container('helm') {
                                sh "helm delete --purge ${releaseName}"
                            }
                            container('kube') {
                                sh "kubectl delete pvc -l release=${releaseName}"
                            }
                        }
                    }
                }
            } catch (e) {
                echo "${e}"
                currentBuild.result = FAILURE
            }
            finally {
                stopElasticsearch()
            }
        }
    }
}


def setElasticsearchEndPoint(addr, port) {
    env.ELASTICSEARCH_ADDR = addr
    env.ELASTICSEARCH_PORT = port
}

def hostPort(container, port) {
    return sh(script: "docker inspect -f '{{(index (index .NetworkSettings.Ports \"${port}/tcp\") 0).HostPort}}' ${container.id}", returnStdout: true).trim()
}

def containerIP(container) {
    return sh(script: "docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${container.id}", returnStdout: true).trim()
}