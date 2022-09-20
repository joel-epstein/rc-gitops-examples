
# Grocerylist

A greymatter.io tenant GitOps repository using CUE! :rocket:

## Prerequisites

* `greymatter` CLI v4.4+
* [CUE](https://cuelang.org/docs/install/)

## Getting Started

Let's get to know the in's and out's of a greymatter.io project!

### CUE

We write mesh configurations in [CUE](https://cuelang.org/), a fantastic data
validation language. It's quite cutting edge, but not hard to learn. We put
together a quick crash course you can read in TUTORIAL.md. You can also
checkout the official [CUE documentation](https://cuelang.org/docs/), [cuetorials](https://cuetorials.com/),
and the [CUE playground](https://cuelang.org/play/#cue@export@cue).

### Creating the example Grocery Store Project

`greymatter init` comes bundled with a full end-to-end example of a grocery store project. 
To generate, run the following command:
```
greymatter init --dir store --example grocerystore
```

### Creating a project scaffold

`greymatter init` also supports creating an empty project. This includes an edge node,
an inputs file, a greymatter.io sync manifest, and a prefetched greymattter.io v1.8 dependencies.
Try running the following:
```
greymatter init --dir project myproject
```

## Project Layout

What comes in a greymatter.io project?

* `cue.mod`: A directory that marks this repo as a cue module.
* `cue.mod/module.cue`: Contains our module name: "examples.module". CUE modules
are logical groupings of packages and enable certain features like imports.
* `cue.mod/pkg`: A package that holds all Grey Matter and Envoy config
CUE schemas as well as other CUE fetched dependencies.
* `greymatter`: The target directory for your project CUE. All greymatter.io service configurations 
will live in this folder regardless of the package.
* `greymatter/core`: This directory hosts greymatter.io specific functionality such as edge nodes, bridges,
and other various core features.
* `./greymatter/inputs.cue`: A CUE file in `package grocerylist` that contains
defaults, overrides, and user generated values. This is the entry point to your configuration pipeline.
* `./greymatter/intermediates.cue`: A CUE file in `package grocerylist` containing
specialized greymatter.io CUE. This is not meant to be edited.
* `EXPORTS.cue`: A file storing the final CUE keys to export. The fields must be
structured as arrays of configs, so that the greymatter.io CLI can parse it.
* `k8s`: A folder to host Kubernetes manifests.
* `k8s/sync.yaml`: A stateful set deploying the greymatter.io sync service.
* `TUTORIAL.md`: an introduction to CUE! :rocket:

  

## Exploring Config Outputs

The `EXPORTS.cue` file renders your configurations you've defined in the
`grocerylist` package. This includes all configuration in
`greymatter/inputs.cue`,  and your final service configurations in
`greymatter/core` + `greymatter/grocerylist`.

You can evaluate the final output by running the following commands:
```sh
# evaluate all configurations
cue eval -c EXPORTS.cue --out json -e configs

# evaluate full output of EXPORTS.cue
cue eval EXPORTS.cue
```

## Applying Configs to a Mesh

### Prerequisites

- An operator managed greymatter.io mesh

### Setup

To apply the configurations provided through this project scaffold,
we recommend deploying the bundled sync service. There are a few things
to do before we launch that sync StatefulSet:

- Install the SSH key secret
```
# GitOps SSH key
# EDIT THIS to reflect your own, or some other SSH private key with access,
# to the repository you would like the operator to use for GitOps.
kubectl create secret generic greymatter-sync-secret \
    --from-file=ssh-private-key=$HOME/.ssh/id_ed25519 \
    --from-literal=password="REDACTED" \
    -n $MY_NAMESPACE
```

> NOTE: Please be sure that the git remote provided in the manifests/sync.yaml file is accurate and accessible.

Make sure to apply the starter k8s manifests in the `./k8s` folder.

```bash
kubectl apply -f ./k8s/manifests.yaml -n $MY_NAMESPACE # this file contains your project edge
kubectl apply -f ./k8s/sync.yaml -n $MY_NAMESPACE # this deploys the greymatter.io sync service
```

### Deployment

greymatter.io supports GitOps as a first-class function. Deploying new services is as easy 
applying a manifest and committing!

Given you have an existing manifest for your service, first deploy it into an operator watched namespace
with the proper sidecar annotations in the Kubernetes object `metadata` field:
```yaml
# Deployment metadata
metadata:
  name: my-new-service
  namespace: my-namespace
  annotations:
    greymatter.io/inject-sidecar-to: 10809
  
...

# container spec metadata 
metadata:
  labels:
    greymatter.io/cluster: my-new-service # this is required to associate your service with the defined upstream in greymatter.
```

Then generate your greymatter.io configurations with the CLI:
```
greymatter init service --type=http --dir=greymatter/myproject --port 8080 --package=myproject myrestapi
```
Once that is generated add the service to the top file EXPORTS.cue.
After doing so, make a commit to your remote repository that you pointed the deployed sync service to and push! 
After a few moments your service should show up in the greymatter.io intelligence 
dashboard and go green once the sidecar can reach the upstream service.

### Using Secure Mode

By default, `greymatter init` will inject your service configurations with full mutual TLS termination happening at the sidecar. 
This means we'll have to create some certificates and mount them in a specific location on disk of each data-plane proxy container. 
We recommend using Kubernetes secrets and volume mounts to independently manage certificates for sidecars in their respective namespaces.

#### Securing Your Gateway
A hook is provided for setting up TLS on the given edge gateway for your project. Please create a secret at the following location:
```
kubectl create secret generic greymatter-grocerylist-edge-certs \
	--from-file=ca.crt=./ca.crt \
	--from-file=server.crt=./server.crt \
	--from-file=server.key=./server.key \
	-n $MY_NAMESPACE
```

#### Securing Services

Certificates are required at the following locations in individual sidecar containers:

__Trust:__  `/etc/proxy/tls/sidecar/ca.crt`
 __Certificate:__ `/etc/proxy/tls/sidecar/server.crt`
 __Key:__ `/etc/proxy/tls/sidecar/server.key`
> Note: The path + file name is important and should be exactly what is outlined above.
 
greymatter.io mesh configurations have been setup for your service to look at these paths. 
It is up to you to get them there! Following the pattern defined in the `k8s/manifests.yaml` edge-grocerylist Deployment 
is a great way to get your certs mounted and available to the greymatter.io data plane.

> Note: your enterprise will need to make sure the core mesh configurations support volume mounted certificates
> so sidecars will have the files when the start. If they are not there, registration into the mesh will never occur.

## Troubleshooting and Gotchas

#### No Sidecar Injection?

- You need to add your projects namespace to the `watched_namespaces` 
array in the core greymatter.io enterprise configs.
- Make sure the injection annotations are in the correct location inside your 
StatefulSet/Deployment. *Hint: they should be in the k8s object metadata.*

####  Services not showing up in the greymatter.io dashboard?

- Make sure the `sync.yaml` manifest is pointed at the correct git remote repository. This can be found in the co-located ConfigMap inside the file.
- Verify your generated service as a `#catalog_entry` with proper keys/names.
- Make sure the greymatter.io sync has no reported errors inside the pod logs.
- Verify you have added your services into the `EXPORTS.cue` configuration arrays.

#### CUE is not evaluating?

- Make sure your intermediates.cue/inputs.cue package matches your service.cue's package. If they do not, then CUE will not evaluate them together.
- Verify all imports/package names are correct.

#### Still stuck?

Check out our [troubleshooting guide](https://docs.greymatter.io/troubleshoot/errors/) at docs.greymatter.io. 
