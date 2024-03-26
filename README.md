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

*  kubectl patch nodepool testarm64 --type merge -p '{"spec":{"template":{"metadata":{"annotations":{"restart/epoch":"'"$(date +%s)"'"}}}}}' 
* kubectl get pod -w 
* kubectl get events -w 
