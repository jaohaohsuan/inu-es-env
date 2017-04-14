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

            try {
                stage('prepare') {
                    checkout scm
                    esContaienr = docker.image('docker.elastic.co/elasticsearch/elasticsearch:5.3.0')
                                        .run('-e "xpack.security.enabled=false" -e "http.host=0.0.0.0" -e "transport.host=0.0.0.0"')

                    timeout(time: 60, unit: 'SECONDS') {
                        waitUntil {
                            def r = sh script: 'curl -XGET http://$ELASTICSEARCH_ADDR:$ELASTICSEARCH_PORT?pretty', returnStatus: true
                            return (r == 0)
                        }
                    }
                }
                
                stage('config') {
                    env.ELASTICSEARCH_ADDR = "${containerIP(esContaienr)}"
                    env.ELASTICSEARCH_PORT = '9200'
                    
                    parallel LogsIndexTemplate: {
                        ansiblePlaybook colorized: true, playbook: 'logs-index-template.yaml', inventory: 'hosts', extras: ''
                    }, StoredQueryIndex: {
                        ansiblePlaybook colorized: true, playbook: 'stored-query-config.yaml', inventory: 'hosts', extras: ''
                    },
                    failFast: false
                }

            } catch (e) {
                echo "${e}"
                currentBuild.result = FAILURE
            }
            finally {
                esContaienr.stop()
                step([$class         : 'LogParserPublisher', failBuildOnError: true, unstableOnWarning: true, showGraphs: true,
                      projectRulePath: 'jenkins-rule-logparser', useProjectRule: true])
            }
        }
    }
}

def hostPort(container, port) {
    return sh(script: "docker inspect -f '{{(index (index .NetworkSettings.Ports \"${port}/tcp\") 0).HostPort}}' ${container.id}", returnStdout: true).trim()
}

def containerIP(container) {
    return sh(script: "docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${container.id}", returnStdout: true).trim()
}