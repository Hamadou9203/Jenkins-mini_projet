pipeline{
    agent {
               docker{
                  image 'docker:dind'
                  args '-v /tmp/app:/app --privileged'
                }
            }
    environment{
       MYSQL_CONTAINER = 'mysql-pay' 
       INIT_DB= '/tmp/app/src/main/resources/database/create.sql'
       DB_DIR='/tmp/create.sql'
       TERRAFORM_DIR = '/app/review-iac'
       IMAGE_NAME= 'paymybuddy-img'
       REGISTRY_USER= 'meskine'
       CONTAINER_NAME= 'paymybuddy-jenkins'
       EXT_PORT= "8085"
       INT_PORT= "8080"
       DOMAIN="172.17.0.1"
       SSH_USER="ubuntu"
       TAG="${env.GIT_BRANCH}-${env.BUILD_ID}".replaceAll('^origin/', '')
       REPO= "/tmp/app"
       SONARQUBE_URL  = "sonarcloud.io"
       STG_URL="ec2-18-208-223-232.compute-1.amazonaws.com"
       PROD_URL="ec2-54-204-232-85.compute-1.amazonaws.com"
       ROOT_PASSWORD=credentials('mysql-password')
       AWS_ACCESS_KEY = credentials('aws-access-key-id')
       AWS_SECRET_KEY = credentials('aws-secret-access-key')
       TF_VAR_region         = 'us-east-1'
       
    }
   
    stages{
        stage('recuperer les codes git'){
            steps{
                script{
                 checkout scm
                }
                 
            }
        }
        stage('se situer'){
            steps{
                script{
                 sh '''
                    rm -rf /app/.mvn /app/*
                    mv  * .mvn  /app/
                    '''
                }
                 
            }
        }
        
        stage('demarrer la base sql '){
            steps{
                script{
                    sh '''
                    docker stop ${MYSQL_CONTAINER}  || echo "no container is running"
                    docker rm ${MYSQL_CONTAINER}  || echo "no container is running"
                    '''
                    sh 'docker run --name ${MYSQL_CONTAINER} -p 3306:3306 -v ${INIT_DB}:/docker-entrypoint-initdb.d/create.sql -e MYSQL_ROOT_PASSWORD=$ROOT_PASSWORD -d mysql'
                }
            }
            
        }
        
        stage('install maven '){
            agent {
               docker{
                  image 'maven:3.8.5-openjdk-17' 
                   args '-v /tmp/app:/app'
                }
            }
            steps{
                script {
                   echo 'building the projet with maven'
                   sh 'cd /app && mvn clean install'
                } 
            }
        }
        stage('analyse statique '){
            environment{
               TOKEN = credentials('token-sonar')
            }
            steps{
                script{
                    sh 'echo " starting sonnar scanning"'
                    sh '''
                     docker run \
                       --rm \
                       -e SONAR_HOST_URL="https://${SONARQUBE_URL}"  \
                       -e SONAR_TOKEN=$TOKEN \
                       -v "$REPO:/usr/src" \
                        sonarsource/sonar-scanner-cli \
                        -Dsonar.projectKey=mon-projet-jenkins \
                        -Dsonar.organization=hamadou9203 \
                        -Dsonar.sources=src/main/java \
                        -Dsonar.java.binaries=target/classes
                    '''
                }
            }
        }
        stage('build de image'){
            steps{
                script{
                sh """
                  cd /app && docker build -t $IMAGE_NAME:$TAG .
                """
                }
            }

        }
        stage('run tests app'){
            steps{
                script{
                    sh """
                    docker stop ${CONTAINER_NAME}  || echo 'no container is running'
                    docker rm ${CONTAINER_NAME}  || echo 'no container is running'
                    docker run --name ${CONTAINER_NAME} -d -p $EXT_PORT:$INT_PORT ${IMAGE_NAME}:$TAG
                    sleep 5 
                    """
                }
            }
        }
        stage('test Acceptance'){
            agent {
                docker{
                    image 'alpine'
                }
            }
            steps{
                script{
                    test("acceptance","${env.DOMAIN}", "${env.EXT_PORT}")
                }
            }
        }
        stage('release'){
            environment{
               DOCKERHUB_PWD = credentials('dockerhub-credentials')
            }
            steps{
                script{
                   sh '''
                      echo $DOCKERHUB_PWD | docker login -u $REGISTRY_USER --password-stdin
                      docker tag $IMAGE_NAME:$TAG $REGISTRY_USER/$IMAGE_NAME:$TAG
                      docker tag $IMAGE_NAME:$TAG $REGISTRY_USER/$IMAGE_NAME:latest
                      docker push $REGISTRY_USER/$IMAGE_NAME:$TAG
                      docker push $REGISTRY_USER/$IMAGE_NAME:latest
                   '''
                }
            }
        }
        stage("deploy review"){
            agent {
               docker{
                  image 'jenkins/jnlp-agent-terraform' 
                  args '-v /tmp/app:/app '
                }
            }
            when{
              expression { GIT_BRANCH == 'origin/dev_features' }
              
            }
            steps{
                  script{
                    withCredentials([sshUserPrivateKey(credentialsId: 'aws-credentials', keyFileVariable: 'PRIVATE_KEY')]) {
                    sh' cd ${TERRAFORM_DIR} && terraform init'
                    sh 'sleep 20'
                    sh 'cd ${TERRAFORM_DIR} && terraform validate'
                    sh """
                     cd ${TERRAFORM_DIR} && terraform apply -auto-approve -var="ssh_key=${PRIVATE_KEY}"
                     """
                    sh 'sleep 60'
                    def publicIp = sh(script: 'cd /app/review-iac && terraform output -raw ec2_public_ip', returnStdout: true).trim()
                    echo "Instance Public IP: ${publicIp}"
                    echo "deployement de la base de donnée mysql pour revue"
                    deploydb( "${publicIp}", "${env.MYSQL_CONTAINER}", "/tmp/data/create.sql", "${env.SSH_USER}", "${env.ROOT_PASSWORD}" )
                  //  sh 'docker run --name ${MYSQL_CONTAINER} -p 3306:3306 -v ${INIT_DB}:/docker-entrypoint-initdb.d/create.sql -e MYSQL_ROOT_PASSWORD=$ROOT_PASSWORD -d mysql'
                    echo "deploiement de l'application pour la revue"
                    deploy("review", "${publicIp }", "${env.REGISTRY_USER}", "${env.IMAGE_NAME}", "${env.TAG}", "${env.CONTAINER_NAME}", "${env.EXT_PORT}", "${env.INT_PORT}", "${env.SSH_USER}")
                }
                  }        
            }
        }
        stage("go stop  review"){
            agent {
               docker{
                  image 'jenkins/jnlp-agent-terraform' 
                  args '-v /tmp/app:/app '
                }
            }
            when{
              expression { GIT_BRANCH == 'origin/dev_features' }
              
            }
            steps {
                script {
                    // Attendre une action manuelle pour confirmer la destruction des ressources
                    def userInput = input message: 'Confirmez-vous la destruction des ressources ?', parameters: [
                        booleanParam(defaultValue: true, description: 'Confirmer la destruction des ressources', name: 'confirm_destroy')
                    ]
                    echo "Paramètre confirm_destroy: ${userInput}"
                    // Vérifie si l'utilisateur a confirmé la destruction
                    if (userInput) {
                        echo "Les ressources seront détruites."
                    } else {
                        echo "La destruction des ressources a été annulée."
                        sh 'cd ${TERRAFORM_DIR} && terraform destroy -auto-approve'
                    }
                }
            }

        }
    
        stage("Deploy-staging"){
            when{
              expression { GIT_BRANCH == 'origin/main' }
              
            }
            steps{
                script{
                    deploy("staging", "${env.STG_URL}", "${env.REGISTRY_USER}", "${env.IMAGE_NAME}", "${env.TAG}", "${env.CONTAINER_NAME}", "${env.EXT_PORT}", "${env.INT_PORT}", "${env.SSH_USER}")
                    }

                }
            

        }
        stage('test staging'){
            agent {
                docker{
                    image 'alpine'
                }
            }
            when{
              expression { GIT_BRANCH == 'origin/main' }
             
            }
            steps{
                script{
                  test("staging","${env.STG_URL}", "${env.EXT_PORT}") 
                }  
            }
        }
        stage("Deploy-production"){
            when{
              expression { GIT_BRANCH == 'origin/main' }
              
            }
            steps{
                script{
                    deploy("prod", "${env.PROD_URL}", "${env.REGISTRY_USER}", "${env.IMAGE_NAME}", "${env.TAG}", "${env.CONTAINER_NAME}", "${env.EXT_PORT}", "${env.INT_PORT}", "${env.SSH_USER}")
                }

            }
         }
        stage('test production'){
            agent {
                docker{
                    image 'alpine'
                }
            }
            when{
              expression { GIT_BRANCH == 'origin/main' }
             
            }
            steps{
                script{
                  test("prod","${env.PROD_URL}", "${env.EXT_PORT}") 
                }  
            }
        }
        stage('clen up environement '){
            steps{
                script{
                    sh """
                     docker stop ${CONTAINER_NAME} 
                     docker rm ${CONTAINER_NAME} 
                     docker stop ${MYSQL_CONTAINER} 
                     docker rm ${MYSQL_CONTAINER} 
                     docker rmi $IMAGE_NAME:$TAG
                     docker rmi $REGISTRY_USER/$IMAGE_NAME:$TAG
                     docker rmi mysql
                    """
                }
            }
        }

    }
    post {
        always {
            // Nettoyage après le pipeline
            echo 'Pipeline terminé'
        }

        success {
            echo 'Infrastructure déployée avec succès'
        }

        failure {
            echo 'Échec du déploiement'
            sh """
            docker rmi $IMAGE_NAME:$TAG
            docker rmi $REGISTRY_USER/$IMAGE_NAME:$TAG
            """
        }
    }
}

def deploy(envrt, url, dockerUser, imageName, tag, containerName,extport,intport,sshUser ){
    echo "deploying to shell-script to ec2 en ${envrt}"
    def pullcmd="docker pull $dockerUser/$imageName:$tag"
    def stopcmd=" docker stop $containerName || echo 'Container not running'"
    def rmvcmd=" docker rm $containerName || echo 'Container not found'"
    def runcmd="docker run -d -p $extport:$intport  --name $containerName $dockerUser/$imageName:$tag"
    sshagent(['aws-credentials']){
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${stopcmd}"
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${rmvcmd}"
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${pullcmd}"
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${runcmd}"
    }
}

def test(envrt, url, extport){
   sh 'sleep 40'
   sh 'apk --no-cache  add curl'
   echo " test ${envrt}"
   sh " curl http://${url}:$extport "
}

def deploydb( url, containerName, dir_db, sshUser, psw ){
    def pullcmd="docker pull mysql"
    def stopcmd=" docker stop $containerName || echo 'Container not running'"
    def rmvcmd=" docker rm $containerName || echo 'Container not found'"
    def runcmd="docker run -d -p 3306:3306 -v $dir_db:/docker-entrypoint-initdb.d/create.sql --name $containerName -e MYSQL_ROOT_PASSWORD=$psw mysql"
    sshagent(['aws-credentials']){
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${stopcmd}"
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${rmvcmd}"
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${pullcmd}"
    sh "ssh -o StrictHostKeyChecking=no $sshUser@${url} ${runcmd}"
}
}
