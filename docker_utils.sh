#!/bin/sh
echo $1

if [ "$1" == "build" ]; then
    docker build -f Dockerfile --tag=bcbi/solrplant_api .
elif [ "$1" == "run" ]; then
    docker run -d -p 5005:5005 --net="host" --restart always --name solrplant_api bcbi/solrplant_api
elif [ "$1" == "push" ]; then
    docker push bcbi/solrplant_api
elif [ "$1" == "pull" ]; then
    docker pull bcbi/solrplant_api
elif [ "$1" == "rm" ]; then
    docker rm bcbi/solrplant_api
else
    echo "First argument must be one of the following strings: build, run, run-dev, push, pull, rm"
fi
