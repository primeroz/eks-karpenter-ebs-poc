### Notes

* Nodes have `Shutdown Graceful settings enabled` through nodeclass userdata ( which is run before the eks-boostrap.sh script in karpenter nodes )
```
  userData: |
    #! /bin/bash
    echo -e "InhibitDelayMaxSec=45\n" >> /etc/systemd/logind.conf
    systemctl restart systemd-logind
    echo "$(jq ".shutdownGracePeriod=\"45s\"" /etc/kubernetes/kubelet/kubelet-config.json)" > /etc/kubernetes/kubelet/kubelet-config.json
    echo "$(jq ".shutdownGracePeriodCriticalPods=\"15s\"" /etc/kubernetes/kubelet/kubelet-config.json)" > /etc/kubernetes/kubelet/kubelet-config.json
```
* Some of the tests, like `kubectl delete node` and `kubectl nodeclaim` rely on the karpenter finalizer to perform a `clean drain` of the node 
* Karpenter itself is aware, and is [working / discussing](https://kubernetes.slack.com/archives/C02SFFZSA2K/p1711453746441689?thread_ts=1711382776.959519&cid=C02SFFZSA2K), how to rework the logic around node termination so the node does not get removed as soon as the delete signal is sent 
  * Until then the `ebs csi node preStop hook` run by `node shutdown manager` will fail since the `node object` in etcd is not available by the time it runs

### EKS 1.26 with standard installation of EBS CSI Driver helm chart

```
➜ kubectl version -o json | jq .serverVersion.gitVersion
"v1.26.14-eks-b9c9ed7"

➜ kubectl get node -l karpenter.sh/nodepool=testarm64 -o json | jq '.items[0]| .status.nodeInfo.kubeletVersion'
"v1.26.12-eks-5e0fdde"
```

#### Tests 

* **Delete node with karpenter finalizer** - `kubectl delte node XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Delete nodeclaim with karpenter finalizer** - `kubectl delete nodeclaim XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Patch nodepool to replace nodes through Drift manager** -> `kubectl patch nodepool testarm64 --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"restart/epoch":"'"$(date +%s)"'"}}}}}'`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Consolidation** -> `TODO`
* **Spot Instance Termination with SQS Event** -> initiate termination through AWS UI
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`

### EKS 1.27 with standard installation of EBS CSI Driver helm chart

```
make tf/apply CLUSTER_VERSION=1.27
```

```
➜ kubectl version -o json | jq .serverVersion.gitVersion
"v1.27.11-eks-b9c9ed7"

➜ kubectl get node -l karpenter.sh/nodepool=testarm64 -o json | jq '.items[0]| .status.nodeInfo.kubeletVersion' 
"v1.27.9-eks-5e0fdde"
```

#### Tests 

* **Delete node with karpenter finalizer** - `kubectl delte node XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Delete nodeclaim with karpenter finalizer** - `kubectl delete nodeclaim XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Patch nodepool to replace nodes through Drift manager** -> `kubectl patch nodepool testarm64 --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"restart/epoch":"'"$(date +%s)"'"}}}}}'`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Consolidation** -> Grow statefulset to 2  - cordon node - evict one pod uncordon - grow to 5 - wait for consolidation
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Spot Instance Termination with SQS Event** -> initiate termination through AWS UI
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`

### EKS 1.28 with standard installation of EBS CSI Driver helm chart

```
make tf/apply CLUSTER_VERSION=1.28
```

```
➜ kubectl version -o json | jq .serverVersion.gitVersion      
"v1.28.7-eks-b9c9ed7"

➜ kubectl get node -l karpenter.sh/nodepool=testarm64 -o json | jq '.items[0]| .status.nodeInfo.kubeletVersion' 
"v1.28.5-eks-5e0fdde"
```

#### Tests 

* **Delete node with karpenter finalizer** - `kubectl delte node XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Delete nodeclaim with karpenter finalizer** - `kubectl delete nodeclaim XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Patch nodepool to replace nodes through Drift manager** -> `kubectl patch nodepool testarm64 --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"restart/epoch":"'"$(date +%s)"'"}}}}}'`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`

### EKS 1.29 with standard installation of EBS CSI Driver helm chart

```
make tf/apply CLUSTER_VERSION=1.29
```

```
➜ kubectl version -o json | jq .serverVersion.gitVersion
"v1.29.1-eks-b9c9ed7"

➜  kubectl get node -l karpenter.sh/nodepool=testarm64 -o json | jq '.items[0]| .status.nodeInfo.kubeletVersion'
"v1.29.0-eks-5e0fdde"
```

#### Tests 

* **Delete node with karpenter finalizer** - `kubectl delte node XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Delete nodeclaim with karpenter finalizer** - `kubectl delete nodeclaim XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Patch nodepool to replace nodes through Drift manager** -> `kubectl patch nodepool testarm64 --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"restart/epoch":"'"$(date +%s)"'"}}}}}'`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`


### EKS 1.29 with change of tolerations (to not tolerate karpenter=disrupting ) on the EBS Driver so that karpenter will drain it as part of the node draining  as suggested on karpenter slack

As described in [Karpenter Slack](https://kubernetes.slack.com/archives/C02SFFZSA2K/p1711452731785299?thread_ts=1711382776.959519&cid=C02SFFZSA2K) the fact that ebs csi driver tolerates the `disruption taint` from karpenter will prevent karpenter from draining the pod. 

Try to make ebs daemonset not tolerate the taint and see if the pod gets drained as part of node draining from karpenter 

```
make ebs/install-karpenter-tolerations
```

#### Tests 

* **Delete node with karpenter finalizer** - `kubectl delte node XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Delete nodeclaim with karpenter finalizer** - `kubectl delete nodeclaim XXX`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`
* **Patch nodepool to replace nodes through Drift manager** -> `kubectl patch nodepool testarm64 --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"restart/epoch":"'"$(date +%s)"'"}}}}}'`
  * :x: -> `Trigger Multi Attach error with 6 minutes wait`


* The kube-system/ebs-csi-node pod is not being evicted by karpenter as part of the drain after the inflate pod , but this does not address the problem :thinking-face:
```
default       0s          Normal    Evicted                      pod/inflate-arm64-0                             Evicted pod
kube-system   0s          Normal    Evicted                      pod/ebs-csi-node-cp49h                          Evicted pod
kube-system   0s          Normal    Killing                      pod/ebs-csi-node-cp49h                          Stopping container ebs-plugin
kube-system   0s          Normal    Killing                      pod/ebs-csi-node-cp49h                          Stopping container liveness-probe
kube-system   0s          Normal    Killing                      pod/ebs-csi-node-cp49h                          Stopping container node-driver-registrar

... some time ...
default       0s          Warning   FailedAttachVolume            pod/inflate-arm64-0                                Multi-Attach error for volume "pvc-10104513-ea96-432e-868e-330eb14ea2bb" Volume is already exclusively attached to one node and can't be attached to another
```
