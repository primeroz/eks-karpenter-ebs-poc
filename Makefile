.PHONY: tf/init tf/validate tf/plan tf/apply tf/destroy tf/all

tf/init:
	terraform init

tf/validate: tf/init
	terraform fmt -recursive
	terraform validate

tf/plan: tf/validate
	terraform plan
	
tf/apply: tf/plan 
	terraform apply
	
tf/destroy:
	terraform destroy
