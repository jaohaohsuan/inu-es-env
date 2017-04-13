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

            def hostPort(container, port) {
              return sh(script: "docker inspect -f '{{(index (index .NetworkSettings.Ports \"${port}/tcp\") 0).HostPort}}' ${container.id}", returnStdout: true)
            }

            try {
                stage('prepare') {
                    checkout scm
                    esContaienr = docker.image('docker.elastic.co/elasticsearch/elasticsearch:5.3.0')
                                        .run('-P -e "xpack.security.enabled=false" -e "http.host=0.0.0.0" -e "transport.host=127.0.0.1"')
                }

                stage('test') {
                    echo "${hostPort(esContaienr, '9200')}"
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