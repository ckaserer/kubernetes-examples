# Excercise Statefulset

Common requirements for stateful applications include the ability to support sticky sessions. Let's take a look on how to implement this in Red Hat OpenShift or Kubernetes. The excercise can be done either on OpenShift or Kubernetes. With OpenShift we will use additional OpenShift resource types that are not available in Kubernetes (e.g Routes in OpenShift vs Ingress in Kubernetes).

**Out of scope** - we will not cover application level session replication as this is application or middleware specific.

In this excercise we will work with a helm chart to install a simple application to showcase sticky sessions. Hence our prerequirements are as follows

* OpenShift or Kubernetes
* helm

To start the excercise we need to update our `values.yaml` to allow access from outside th cluster to our application depending on which platform we are using.

**For Kubernetes** we enable the ingress resource by setting `create` to `true` and the `host` to a hostname that resolve to an IP of our cluster.

```
# Kubernetes
ingress:
  create: true
  host: "hello-ckaserer.apps.p.aws.ocp.gepardec.com"
```

**For OpenShift** we enable the route resource by setting `create` to `true`.

```
# OpenShift
route:
  create: true
```

Okay, now that we have customized our configuration we can continue to install the resources from the helm chart via

```
$ helm install hello .
```

Helm installs based on the config specified in `values.yaml`
* a statefulset running our example application with 3 replica
* a ServiceAccount to run our statefulset
* a service
* an ingress or a route to access our application

To verify that our application is working as expected we can open the newly created ingress/route in a browser. 

**With Kubernetes** you can use the cli to get the ingress information via

```
$ kubectl get ingress hello
```

**With OpenShift** you can either find the correct URL in the OpenShift Console (Web) or via the cli

```
$ oc get route hello
```

As long as you do not delete the cookies you are using to access the website from the browser and the pod that is serving your request is not terminated you will always end up on the same pod.

Let's take a look on what makes the route in **OpenShift** sticky. Through annotations we can add additional information to the router instance exposing the route. By adding the annotation `router.openshift.io/cookie_name` we tell the router to set and track cookies with the name `hello-1`. Cookies are automatically used for https routes, but for http routes we need to set the `cookie_name` to enable cookies for http traffic.

```
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: hello
  annotations:
    router.openshift.io/cookie_name: "hello-1"
...
```

What happens when we manually kill the pod we are currently connected to? Let's find out! First we need to be quick here or Kubernetes/OpenShift will have already spun another replica up and you might end up on a pod with the same name.

So be quick and terminate the pod that you are currently connect to (e.g. hello-0) by executing

**Kubernetes**

```
$ kubectl delete pod hello-0
```

**OpenShift** 

```
$ oc delete pod hello-0
```

Quickly open your browser and refresh the page. You should get a response from another replica now.

Now let's do the same but with curl from our comandline

**Kubernetes**

```
$ for I in $(seq 1 8); \
  do \
      curl -s \
      http://$(kubectl get ingress hello -o jsonpath='{.spec.rules[0].host}') | grep "Server name"; \
  done
```

**OpenShift**

```
$ for I in $(seq 1 8); \
  do \
      curl -s \
      http://$(oc get route hello -o jsonpath='{.spec.host}') | grep "Server name"; \
  done
```

When you run curl multiple times as we do with the loop here you should realize that the backend pod varies. But why?! Well we curl the website without storing our cookie and therefore every request appears as a new client.

In order to get the same behaviour as we have seen in the browser beforhand we need to store and use a cookie.

**Kubernetes**

```
$ curl -s -o /dev/null \
    --cookie-jar cookies.txt \
    http://$(kubectl get ingress hello \
    -o jsonpath='{.spec.rules[0].host}')
```

**OpenShift**

```
$ curl -s -o /dev/null \
    --cookie-jar cookies.txt \
    http://$(oc get route hello \
    -o=jsonpath='{.spec.host}')
```

Perfect, now we got our cookie file. Next we can use the cookie file for multiple curl commands and realize that every request is served by the same pod.


**Kubernetes**

```
$ for I in $(seq 1 8); \
  do \
      curl -s \
      --cookie cookies.txt \
      http://$(kubectl get ingress hello -o jsonpath='{.spec.rules[0].host}') | grep "Server name"; \
  done
```

**OpenShift**

```
$ for I in $(seq 1 8); \
  do \
      curl -s \
      --cookie cookies.txt \
      http://$(oc get route hello -o=jsonpath='{.spec.host}') | grep "Server name"; \
  done
```

Wonderful, that's all for now.

---

## Conclusion

We installed a statefulset in OpenShift via helm and exposed it via a route. A web browser will automatically store cookies for us and our sticky session works out of the box. We always end up on the same pod unless the pod gets terminated or we delete our cookies.

If we use curl from the commandline we did not get sticky sessions out of the box, since by default curl does not store cookies from one request to the next. We need to store our cookie manually and use it in our curl command in order to get the same behavior as with a web browser.

What happens to the application state associated to my session if the pod is terminated? It's lost. In this example we did not cover application level session replication. If a pod is terminated all sessions of that pod are lost. E.g. if your app has a login functionality and are logged in before your pod terminates, you will be logged out after the pod terminated and another pod, unaware of your session, handles your request.

---

**Source**
* https://livebook.manning.com/book/openshift-in-action
* https://kubernetes.io/docs/concepts/services-networking/service/
* https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html/architecture/core-concepts
* https://docs.openshift.com/container-platform/4.1/networking/routes/route-configuration.html#nw-annotating-a-route-with-a-cookie-name_route-configuration