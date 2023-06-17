# FeatBit Helm Chart

[FeatBit](https://github.com/featbit/featbit) is an open-source feature flags management tool.
This Helm chart bootstraps a [FeatBit](https://github.com/featbit/featbit) installation on a [Kubernetes](https://kubernetes.io/) cluster using the [Helm](https://helm.sh/) package manager.

## Prerequisites
* Kubernetes >=1.23 <= 1.26
* Helm >= 3.7.0

## Usage 

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

helm repo add featbit https://featbit.github.io/featbit-charts/

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
featbit` to see the charts.

To install the featbit chart:

    helm install <your-release-name> featbit/featbit

To simply upgrade your current release to the latest version of featbit chart:
    
    helm repo update [featbit]
    
    helm upgrade <your-release-name> featbit/featbit


To uninstall the chart:

    helm delete <your-realease-name>

To get the more details of using helm to deploy or maintain your featbit release in the k8s, please refer to
Helm's [documentation](https://helm.sh/docs)
