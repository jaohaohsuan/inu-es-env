properties(
    [
        [
            $class: 'jenkins.model.BuildDiscarderProperty', strategy: [$class: 'LogRotator', numToKeepStr: '5']
        ]
    ]
)
podTemplate(
    label: 'inuesenv',
    containers: [
            containerTemplate(name: 'jnlp', image: 'henryrao/jnlp-slave', args: '${computer.jnlpmac} ${computer.name}', alwaysPullImage: true)
    ],
    volumes: [
            hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock'),
            persistentVolumeClaim(claimName: 'helm-repository', mountPath: '/var/helm/repo', readOnly: false)
    ]) {

    node('inuesenv') {
        ansiColor('xterm') {
            def esContaienr
            def stopElasticsearch = { }
            try {
                
                stage('prepare') {
                    checkout scm

                    if (params.ELASTICSEARCH_ADDR && params.ELASTICSEARCH_PORT) {   
                        echo 'skipped'
                        setElasticsearchEndPoint(params.ELASTICSEARCH_ADDR, params.ELASTICSEARCH_PORT)
                    }
                    else {
                        
                        esContaienr = docker.image('henryrao/elasticsearch:2.3.3').run('--privileged -e ES_HEAP_SIZE=128m')

                        stopElasticsearch = { esContaienr.stop() }
                        setElasticsearchEndPoint(containerIP(esContaienr), 9200)
                    }

                    timeout(time: 60, unit: 'SECONDS') {
                        waitUntil {
                            def r = sh script: 'curl -XGET http://$ELASTICSEARCH_ADDR:$ELASTICSEARCH_PORT?pretty', returnStatus: true
                            return (r == 0)
                        }
                    }
                }
                
                stage('config') {
                    
                    parallel IndexTemplate: {
                        ansiblePlaybook colorized: true, playbook: 'logs-index-template.yaml', inventory: 'hosts', extras: ''
                    }, StoredQuery: {
                        ansiblePlaybook colorized: true, playbook: 'stored-query-config.yaml', inventory: 'hosts', extras: ''
                    },
                    failFast: false
                }

                stage('test') {
                    
                    if(params.WITHOUT_FAKEDATA) {
                        echo 'creating fake data skipped'
                    }
                    else {
                        ansiblePlaybook colorized: true, playbook: 'sample-data.yaml', inventory: 'hosts', extras: ''
                    }
                }

                stage('containerize') {
                    withDockerRegistry(url: 'https://index.docker.io/v1/', credentialsId: 'docker-login') {
                        
                        def image = docker.build("henryrao/inuesenv", '.')

                        image.inside {
                            
                            sh '''
                            ansible --version
                            python --version
                            ansible-playbook entrypoint.yaml
                            '''
                        }

                        image.push(env.BRANCH_NAME)
                    }
                }

                stage('package') {
                    docker.image('henryrao/helm:2.3.1').inside('') { c ->
                        sh '''
                        # packaging
                        helm package --destination /var/helm/repo inu-es-env
                        helm repo index --url https://grandsys.github.io/helm-repository/ --merge /var/helm/repo/index.yaml /var/helm/repo
                        '''
                    }
                    build job: 'helm-repository/master'
                }

            } catch (e) {
                echo "${e}"
                currentBuild.result = FAILURE
            }
            finally {
                stopElasticsearch()
                step([$class         : 'LogParserPublisher', failBuildOnError: true, unstableOnWarning: true, showGraphs: true,
                      projectRulePath: 'jenkins-rule-logparser', useProjectRule: true])
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