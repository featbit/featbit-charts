# FeatBit Helm Chart

[FeatBit](https://github.com/featbit/featbit) is an open-source feature flags management tool, which supported self-hosted deployment.
This Helm chart bootstraps a [FeatBit](https://github.com/featbit/featbit) installation on a [Kubernetes](https://kubernetes.io/) cluster using the [Helm](https://helm.sh/) package manager.

## Prerequisites
* Kubernetes >=1.23
* Helm >= 3.7.0

## ⚠️ Dependencies Notice

🚨 **CRITICAL: Bitnami Image Repository Changes (Effective August 2025)**

This chart includes the following infrastructure dependencies which are **strictly for testing and development purposes**:

- **PostgreSQL**: Default primary database *(⚠️ bitnami legacy images only, no update)*
- **MongoDB**: Alternative primary database
- **Redis**: Required caching layer *(⚠️ bitnami legacy images only, no update)*
- **Kafka**: Optional messaging system *(⚠️ bitnami legacy images only, no updates)*
- **ClickHouse**: Optional analytics database *(⚠️ bitnami legacy images only, no updates)*

**For local testing/development**, we provide example configurations in [`charts/featbit/examples/standard/`](./charts/featbit/examples/standard/) that use specific container images:
- [`featbit-standard-local-pg.yaml`](./charts/featbit/examples/standard/featbit-standard-local-pg.yaml) - PostgreSQL + Redis configuration for local Docker Desktop Kubernetes
- [`featbit-standard-local-mongo.yaml`](./charts/featbit/examples/standard/featbit-standard-local-mongo.yaml) - MongoDB + Redis configuration for local Docker Desktop Kubernetes

These examples leverage the default image configurations in `values.yaml`, which specify tested and compatible versions for local development environments.


**For production environments**, we HIGHLY recommend that you use external managed services (your own included):

- **PostgreSQL/MongoDB**: Configure `externalPostgresql` or `externalMongodb` with managed database services (Azure Database for PostgreSQL, AWS RDS, Google Cloud SQL, etc.)
- **Redis**: Configure `externalRedis` with managed Redis services (Azure Cache for Redis, AWS ElastiCache, Google Cloud Memorystore, etc.)
- **Kafka**: Configure `externalKafka` with managed Kafka services (Confluent Cloud, AWS MSK, Azure Event Hubs, etc.)
- **ClickHouse**:  Configure `externalClickhouse` with managed ClickHouse services (ClickHouse Cloud, Altinity.Cloud, etc.)


## Usage 

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add featbit https://featbit.github.io/featbit-charts/
```

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
featbit` to see the charts.

To install the featbit chart:
```
helm install <your-release-name> featbit/featbit [-f <your-values-file>]
```

To simply upgrade your current release to the latest version of featbit chart:

```
helm repo update [featbit]
    
helm upgrade <your-release-name> featbit/featbit [-f <your-values-file>]
```

To uninstall the chart:

```
helm delete <your-realease-name>
```

To get the more details of using helm to deploy or maintain your featbit release in the k8s, please refer to
Helm's [documentation](https://helm.sh/docs)

Note that if your device is based on the arm64 architecture, please use version 0.2.1 and above.

## Expose self-hosted deployment

To use FeatBit, three services must be exposed from the internal network of Kubernetes:

* ui: FeatBit frontend
* api: FeatBit api server
* evaluation server(els): FeatBit data synchronization and data evaluation server

If you cannot access the services using localhost and their default ports, `apiExternalUrl` and `evaluationServerExternalUrl` **_SHOULD_** be reset in the [values.yaml or your own values file with -f flag](https://helm.sh/docs/chart_template_guide/values_files/)

**All the examples here are tested on Minikube base on the embedding postgresql and redis If you need to deploy them to a public cloud or your own private cloud in the production, please contact us.**

### Ingress

Ingress exposes HTTP and HTTPS routes from outside the cluster to services within the cluster. Traffic routing is controlled by rules defined on the Ingress resource.

An Ingress may be configured to give Services externally-reachable URLs, load balance traffic, terminate SSL / TLS, and offer name-based virtual hosting. 

An Ingress controller is responsible for fulfilling the Ingress, usually with a load balancer, though it may also configure your edge router or additional frontends to help handle the traffic.

#### Prerequisites
You must have an Ingress controller to satisfy an Ingress. Only creating an Ingress resource has no effect.

You may need to deploy an Ingress controller such as ingress-nginx. You can choose from a number of [Ingress controllers](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/).

Ideally, all Ingress controllers should fit the reference specification. In reality, the various Ingress controllers operate slightly differently.

Minikube supports ingress-nginx via addons, you can activate the ingress controller via:

```bash
minikube addons enable ingress
```

#### Example for Ingress

Here is a simple [example](./charts/featbit/examples/standard/expose-services-via-ingress.yaml) that show how to use ingress to expose services:
```yaml

apiExternalUrl: "http:/{API host name}"
evaluationServerExternalUrl: "http://{Evaluation Server host name}"

ui:
  ingress:
    enabled: true
    host: {UI host name}


api:
  ingress:
    enabled: true
    host: {API host name}


els:
  ingress:
    enabled: true
    host: {Evaluation Server host name}


```

Note that:
* you should bind the host names that can be resolved by DNS server or map the IPs and host names in the dns hosts file(/etc/hosts in linux and macox) in your local cluster.
* the default ingress class is nginx, set your value in `global.ingressClassName` if needed
* set the annotations in the `<service>.ingress.annotations`, if needed
    for example:
    ``` yaml
    ... 
    ui:
      ingress:
          enabled: true
          host: {UI host name}
          annotations:
              nginx.ingress.kubernetes.io/use-regex: "true"
              nginx.ingress.kubernetes.io/rewrite-target: /$2
              kubernetes.io/tls-acme: "true"
    ...
      
    ```
#### Example for Ingress with TLS

Here is a simple [example](./charts/featbit/examples/standard/expose-services-via-ingress-tls.yaml) that show how to use ingress to expose services with TLS:
```yaml
apiExternalUrl: "https://{API host name, ex: api.featbit.com}"
evaluationServerExternalUrl: "https://{Evaluation Server host name, ex: api.featbit.com}"

ui:
  ingress:
    enabled: true
    host: {UI host name, ex: ui.featbit.com}
    tls:
      enabled: true
      secretName: {your domain cert secret name, ex: "featbit-com-tls-secret"}

api:
  ingress:
    enabled: true
    host: {API host name, ex: api.featbit.com}
    tls:
      enabled: true
      secretName: {your domain cert secret name, ex: "featbit-com-tls-secret"}


els:
  ingress:
    enabled: true
    host: {Evaluation Server host name, ex: els.featbit.com}
    tls:
      enabled: true
      secretName: {your domain cert secret name, ex: "featbit-com-tls-secret"}
```

To create a secret for tls, we suggest you to use cert-manager to manage your auto-renewing ssl certificates, you can refer to [cert-manager](https://cert-manager.io/docs/) to get more details.

If you are using a self-signed certificate, you can create a secret with the following command:

```bash
kubectl create secret tls featbit-com-tls-secret --key /path/to/tls.key --cert /path/to/tls.crt
```

### LoadBalancer
Exposes the Service externally using an external load balancer. K8s does not directly offer a load balancing component; you must provide one, or you can integrate your Kubernetes cluster with a cloud provider.
The 3 services must be assigned an IP before deployment. Especially, we **_MUST_** know the IPs of api and evaluation server in advance.
If the load balancer randomly assigns external IP addresses to services, it can make it difficult to preconfigure parameters. Therefore, we currently **_DO NOT_** recommend to use this approach.

#### Prerequisites

Minikube supports MetalLB to access the service with the external IP address

```bash
# get external ip binding to minikube
minikube ip
# enable the MetalLB minikube add-on.
minikube addons enable metallb
# Configure the external IPs ranges that can be used by MetalLB for the LoadBalancer services.
minikube addons configure metallb
```

#### Static IP
To expose service, we recommend you to bind static external IPs to services, as the following [example](./charts/featbit/examples/standard/expose-services-via-lb-static-ip.yaml)

```yaml

apiExternalUrl: "http://API_EXTERNAL_IP:5000"
evaluationServerExternalUrl: "http://ELS_EXTERNAL_IP:5100"

ui:
  service:
    type: LoadBalancer
    staticIP: {UI_EXTERNAL_IP}

api:
  service:
    type: LoadBalancer
    staticIP: {API_EXTERNAL_IP}

els:
  service:
    type: LoadBalancer
    staticIP: {ELS_EXTERNAL_IP}
```

#### IP Auto Discovery

We also provide a support to discovery automatically Load Balancer service IPs, as the following [example](./charts/featbit/examples/standard/expose-services-via-lb-auto-discovery-ip.yaml):

```yaml

apiExternalUrl: ""
evaluationServerExternalUrl: ""
autoDiscovery: true

ui:
  service:
    type: LoadBalancer

api:
  service:
    type: LoadBalancer

els:
  service:
    type: LoadBalancer
```
Use `kubectl get svc` to obtain the IP addresses.

### NodePort
Exposes the Services on each k8s cluster Node's IP at a static port:

* ui: http://NODE_IP:30025
* api: http://NODE_IP:30050
* evaluation server(els): http://NODE_IP:30100

Set your configurations as the following [example](./charts/featbit/examples/standard/expose-services-via-nodeport.yaml)

```yaml

apiExternalUrl: "http://NODE_IP:30050"
evaluationServerExternalUrl: "http://NODE_IP:30100"

ui:
  service:
    type: NodePort
#    nodePort: 30025

api:
  service:
    type: NodePort
#    nodePort: 30050

els:
  service:
    type: NodePort
#    nodePort: 30100
```


It is generally advisable not to modify the default `nodePort` value unless it conflicts with your k8s node.

#### Get node's IP

Minikube: `minikube ip`


### ClusterIP

If you deployed the FeatBit chart in your cluster using the command `helm install featbit featbit/featbit`

By default, these three services are started using ClusterIP, which means they can only be accessed within the internal network of Kubernetes.

If you are using a single-node installation of Kubernetes cluster such as [Minikube](https://github.com/kubernetes/minikube) or [K3D](https://k3d.io/),

Please use the following command to expose the services, then visit ui in `http://localhost:8081`, set your [client sdk](https://docs.featbit.co/docs/getting-started/4.-connect-an-sdk) with `http://localhost:5100`

```
// ui
kubectl port-forward service/featbit-ui 8081:8081  [--namespace <your-name-space>]
// api
kubectl port-forward service/featbit-api 5000:5000 [--namespace <your-name-space>]
// evaluation server
kubectl port-forward service/featbit-els 5100:5100 [--namespace <your-name-space>]
```

## Conclusion
We understand that not all service deployment methods may be compatible with your cluster. If you encounter any issues or need further assistance in exposing the services, please feel free to reach out to us for support. 
We'll be happy to help you with the specific configuration required for your cluster.
