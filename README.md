# StatefulSet local image resolution issue
## Overview
The goal of this project is to attempt to illustrate the intermittant failure of local image tag reference resolution in OpenShift 4.8.  The symptom is that when the statefulset is applied and is rolling out the image tag in the statefulset configuration is not reliably translated into the image stream reference already present on the cluster and in the namespace.  This causes OpenShift to attempt to pull the image from docker.io where it does not exist, resulting in an ImagePullBackoff error.

## Assumptions
- Your OpenShift cluster verison is 4.8.17
- You have the OpenShift CLI installed

## Steps to reproduce

Login to OpenShift with the CLI and switch to or create a new project for this exercise.

Export your cluster's registry URL to the OS_REG env var
```
export OS_REG="$(oc get -n openshift-image-registry route default-route -o=jsonpath='{.spec.host}'):443"
```

Login to the OpenShift registry: 
```
docker login -u <your-user-name> -p $(oc whoami -t) $OS_REG
```

Create an a empty image stream in yout project using:
```
oc create imagestream --lookup-local=true statefulset-issue-demo
```

Build, tag and deploy the demo, version 1.0.0, for example:
```
./deploy.sh <namespace> 1.0.0
```
At this point is may succeed or fail

If it succeeds and all three pods come up then build, tag, push and deploy another version, 1.0.1 for example.

```
./deploy.sh <namespace> 1.0.1
```

When it fails you caninspect the YAML of the failing pos and notice that the `image` has not be trsanslated or resolved into appropriate image stream reference and OpenShift tries to pull the image from docker.io and that won't work. This error appears in the failing pod's events:

```
Failed to pull image "statefulset-issue-demo:1.0.1": rpc error: code = Unknown desc = Error reading manifest 1.0.1 in docker.io/library/statefulset-issue-demo: errors: denied: requested access to the resource is denied unauthorized: authentication required 
```

This:

```
image: 'statefulset-issue-demo:1.0.1'
```

And the correct translation to something like:

```
image: >-
        image-registry.openshift-image-registry.svc:5000/<namespace>/statefulset-issue-demo@sha256:51fd03cc0aa2a67d7e91491a66ab35fe18945886e721f63223086981e12adf6d
```

It typicaly fails on the second attempt.  

If it succeeds and all three pods come up then build, tag, push deploy another version, 1.0.2 for example. 

Trying a third time doesn't fix it.

I have tried deleteing the failing pod.  That also does not seem to work, and results in the same image pull error.

Scaling the statefulset to 0 replicas and back up also does not seem to work, and results in the same image pull error.

```
oc scale sts statefulset-issue-demo --replicas 0

oc scale sts statefulset-issue-demo --replicas 3
```

So, without anything else to try, I delete the statefulset and every thing else with 

```
oc process -p version=1.0.2 -p environment=<namespace>  -f template.yaml | oc delete -f - 
```

Now just re-deploy it

```
./deploy.sh <namespace> 1.0.0 
```

This typically works, although sometimes last pod that attempts to start up will fail with the same image pull error.

**This is not an acceptable solution because of the statefulness of the applications we are running, which rely on mounted shared volumes to perform leader election. These errors result in an unrecoverable system state that can only be fixed by also removing the shared volumes, which deletes all the persistent data.**


## Cleanup
To clean up after this exercise, running:
```
./cleanup.sh <namespace>
```
Will delete app the resources that were applied and the imagestream.