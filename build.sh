#!/bin/bash -xe
IMAGE_NAME=my-ssh-setup-image
echo $IMAGE_NAME
docker build --platform linux/amd64 -t interbeing/myfmg:${IMAGE_NAME} .
docker push interbeing/myfmg:${IMAGE_NAME}
