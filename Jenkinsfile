pipeline {
    agent { 
        node {label 'bare-metal' }
    } 
    stages {
        stage('Build') { 
            steps {
               
                sh 'mkdir -p CWL/Data/Baseline'
                sh 'mkdir -p CWL/Data/Outputs'
                sh 'docker build -t mgrast/pipeline:testing .' 
                sh 'Setup/check-and-load-docker-volume.sh'
                // sh 'CWL/Inputs/DBs/getpredata.sh CWL/Inputs/DBs/' 
            }
        }
        stage('Test') { 
            steps {
                sh 'docker run -t --rm  -e CREATE_BASELINE=1 -v `pwd`:/pipeline -v pipeline-pre-data:/pipeline/CWL/Inputs/DBs mgrast/pipeline:testing /pipeline/CWL/Tests/testWorkflows.py -v' 
            }
        }
    }
     post {
        always {
             // shutdown container and network
                sh '''
                    set +e
                    docker stop mgrast/pipeline:testing 
                    docker rmi mgrast/pipeline:testing
                    set -e
                    echo Cleanup done
                    '''
        }
    }
}
