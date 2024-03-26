## To install 

* Make sure your environment has Admin access to a AWS Account
* Double check the variables in the Makefile and tfvars
* make tf/plan
* make tf/apply
* make eks/validate
* make ebs/install
* make karpenter/install
* make karpenter/resources
* make k8s/workload
* export KUBECONFIG=/tmp/demo-eu-west-3-kubeconfig
* kubectl get pod -n default 
