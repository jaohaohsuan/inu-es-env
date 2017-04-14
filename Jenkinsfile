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
            hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock')
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
                        esContaienr = docker.image('docker.elastic.co/elasticsearch/elasticsearch:5.3.0')
                                            .run('-e "xpack.security.enabled=false" -e "http.host=0.0.0.0" -e "transport.host=0.0.0.0"')

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