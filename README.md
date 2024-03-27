## To install 

* Make sure your environment has Admin access to a AWS Account
* Double check the variables in the Makefile and tfvars
* make tf/plan
* make tf/apply
* make eks/validate
* make ebs/install
* make karpenter/install
* make karpenter/resources

---
### Create workload for testing

* make k8s/workloads
* export KUBECONFIG=/tmp/demo-eu-west-3-kubeconfig
* kubectl get pod -n default 


---
### Patch nodepool and watch pod 

* kubectl patch nodepool testarm64 --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"restart/epoch":"'"$(date +%s)"'"}}}}}' 
* kubectl get pod -w 
  * watch out for `6m for pod to become running on new node`
* kubectl get events -w 
  * watch out for `Multi-Attach error for volume "pvc-10104513-ea96-432e-868e-330eb14ea2bb" Volume is already exclusively attached to one node and can't be attached to another`

---
### Results

Some results from my testing collected in [Results](./RESULTS.md)

---
### Conclusions

* All version of EKS 1.26 to 1.29 , with Node Graceful Shutdown enabled , are affected by the `multi attach error` problem when using Karpenter with EBS CSI Driver
  * during Drift Manager node replacement
  * during Spot instance interruption 
  * during node Consolidation node replacement
  * when deleting `nodeclaim` or `node` and using karpenter finalizer 
