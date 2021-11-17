#!/bin/bash

namespace=${1?no namespace defined};

app="statefulset-issue-demo"

echo "++> Delete Statefulset version: $version"
oc process -p version=1.0.0 -p environment=$namespace  -f template.yaml | oc delete -f -

echo "++> Delete ImageStream if necessary"
oc delete imagestream $app