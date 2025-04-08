pipeline{
    agent {
               docker{
                  image 'docker:dind'
                  args '-v /tmp/app:/app --privileged'
                }
            }
    environment{
       MYSQL_CONTAINER = 'mysql-paymybuddy' 
       INIT_DB= '/tmp/app/src/main/resources/database/create.sql'
       DB_DIR='/tmp/create.sql'
       IMAGE_NAME= 'paymybuddy-img'
       REGISTRY_USER= 'meskine'
       CONTAINER_NAME= 'paymybuddy-jenkins'
       EXT_PORT= "8085"
       INT_PORT= "8080"
       DOMAIN="172.17.0.1"
       SSH_USER="ubuntu"
       TAG="${env.BUILD_ID}"
       STG_URL="ec2-34-207-235-141.compute-1.amazonaws.com"
       ROOT_PASSWORD=credentials('mysql-password')
    }
   
    stages{
        stage('recuperer les codes de git'){
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
                    ls -al
                    pwd
                    rm -rf /app/.mvn /app/*
                    mv  * .mvn  /app/
                    ls -al /app
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
                    sh 'apk --no-cache  add curl'
                    sh 'curl http://$DOMAIN:$EXT_PORT '
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
                      docker push $REGISTRY_USER/$IMAGE_NAME:$TAG
                   '''
                }
            }
        }
        stage("Deploy-staging"){
            when{
              expression { GIT_BRANCH == 'origin/main' }
              
            }
            steps{
                script{
                    echo "deploying to shell-script to ec2 en staging"
                    def pullcmd="docker pull $REGISTRY_USER/$IMAGE_NAME:$TAG"
                    def stopcmd=" docker stop $CONTAINER_NAME || echo 'Container not running'"
                    def rmvcmd=" docker rm $CONTAINER_NAME || echo 'Container not found'"
                    def runcmd="docker run -d -p $EXT_PORT:$INT_PORT  --name $CONTAINER_NAME $REGISTRY_USER/$IMAGE_NAME:$TAG"
                    sshagent(['aws-credentials']){
                       sh "ssh -o StrictHostKeyChecking=no $SSH_USER@${STG_URL} ${stopcmd}"
                       sh "ssh -o StrictHostKeyChecking=no $SSH_USER@${STG_URL} ${rmvcmd}"
                       sh "ssh -o StrictHostKeyChecking=no $SSH_USER@${STG_URL} ${pullcmd}"
                       sh "ssh -o StrictHostKeyChecking=no $SSH_USER@${STG_URL} ${runcmd}"
                    }

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
                    sh 'sleep 40'
                    sh 'apk --no-cache  add curl'
                    echo " test staging"
                    sh " curl http://${STG_URL}:$EXT_PORT "
                }  
            }
        }

    }
}
