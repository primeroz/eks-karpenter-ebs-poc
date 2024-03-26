CLUSTER_NAME = "demo"
CLUSTER_VERSION = "1.26"
REGION = "eu-west-3"

KARPENTER_VERSION := 0.35.2

KUBECONFIG_PATH := /tmp/$(CLUSTER_NAME)-$(REGION)-kubeconfig
export KUBECONFIG := $(shell echo $(KUBECONFIG_PATH) | sed 's/"//g')
KUBECTL := kubectl --kubeconfig $(KUBECONFIG)
HELM := helm --kubeconfig $(KUBECONFIG)

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

.PHONY: aws/validate eks/kubeconfig eks/validate

aws/validate:
	@aws sts get-caller-identity  > /dev/null

eks/kubeconfig: aws/validate
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME) --kubeconfig $(KUBECONFIG) > /dev/null

eks/validate: eks/kubeconfig
	$(KUBECTL) cluster-info
	$(KUBECTL) get node 

.PHONY: karpenter/install karpenter/resources

karpenter/install:
	$(HELM) upgrade --install karpenter oci://public.ecr.aws/karpenter/karpenter --version "$(KARPENTER_VERSION)" --namespace "karpenter" --create-namespace \
  --set settings.clusterName=$(CLUSTER_NAME) \
  --set settings.interruptionQueue=$(shell terraform output -json | jq .info.value.karpenter.queue_name | sed 's/"//g' ) \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(shell terraform output -json | jq .info.value.karpenter.iam_role_arn | sed 's/"//g' ) \
  --set controller.resources.requests.cpu=1 \
  --set controller.resources.requests.memory=1Gi \
  --set controller.resources.limits.cpu=1 \
  --set controller.resources.limits.memory=1Gi \
  --wait

karpenter/resources:
	cat nodeclass.yaml | \
  NODE_ROLE_NAME=$(shell terraform output -json | jq .info.value.karpenter.node_iam_role_name | sed 's/"//g' )  \
  DISCOVER_SG_TAG_VALUE=$(CLUSTER_NAME) \
  DISCOVER_SUBNET_TAG_VALUE=$(CLUSTER_NAME) \
  envsubst | $(KUBECTL) apply -f -
	
	cat nodepool.yaml |  $(KUBECTL) apply -f -
