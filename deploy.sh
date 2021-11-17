#!/bin/bash

namespace=${1?no namespace defined};
version=${2?no version specified};

app="statefulset-issue-demo"

echo "Building and deploying $app:$version"

echo "++> Create ImageStream if necessary"
oc create imagestream --lookup-local=true $app

echo "++> Building images with tag: $app:$version"
docker build -t $app:$version .

echo "++> Tagging for OpenShift registry: $OS_REG/$namespace/$app:$version"
docker tag $app:$version $OS_REG/$namespace/$app:$version

echo "++> Pushing tag to OpenShift in namespace $namespace"
docker push $OS_REG/$namespace/$app:$version

echo "++> Deploying $app Statefulset version: $version"
oc process -p version=$version -p environment=$namespace  -f template.yaml | oc apply -f -