CLUSTER_NAME = "demo"
CLUSTER_VERSION = "1.26"
REGION = "eu-west-3"

KUBECONFIG_PATH := /tmp/$(CLUSTER_NAME)-$(REGION)-kubeconfig
export KUBECONFIG := $(shell echo $(KUBECONFIG_PATH) | sed 's/"//g')

TERRAFORM := terraform
TF_OPTIONS := -var cluster_name=$(CLUSTER_NAME) -var region=$(REGION) -var cluster_version=$(CLUSTER_VERSION)

.PHONY: tf/init tf/validate tf/plan tf/apply tf/destroy tf/all

tf/init:
	terraform init

tf/validate: tf/init
	terraform fmt -recursive
	terraform validate

tf/plan: tf/validate
	terraform plan $(TF_OPTIONS)
	
tf/apply: tf/validate
	terraform apply $(TF_OPTIONS)
	
tf/destroy:
	terraform destroy $(TF_OPTIONS)

tf/output:
	terraform output -json | jq .info.value

.PHONY: aws/validate eks/kubeconfig

aws/validate:
	@aws sts get-caller-identity  > /dev/null

eks/kubeconfig: aws/validate
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME) --kubeconfig $(KUBECONFIG) > /dev/null

eks/validate: eks/kubeconfig
	kubectl --kubeconfig $(KUBECONFIG) cluster-info
	kubectl --kubeconfig $(KUBECONFIG) get node 
