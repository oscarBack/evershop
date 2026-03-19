.PHONY: tf-dev tf-qa tf-prod tf-u-dev tf-u-qa tf-u-prod fmt validate

tf-dev:
	aws sso login --profile aws-evershop-dev
	terraform init
	terraform workspace select dev || terraform workspace new dev
	terraform plan -var-file="dev.hcl"

tf-qa:
	aws sso login --profile aws-evershop-qa
	terraform init
	terraform workspace select qa || terraform workspace new qa
	terraform plan -var-file="qa.hcl"

tf-prod:
	aws sso login --profile aws-evershop-prod
	terraform init
	terraform workspace select prod || terraform workspace new prod
	terraform plan -var-file="prod.hcl"

tf-u-dev:
	aws sso login --profile aws-evershop-dev
	terraform init -upgrade
	terraform workspace select dev || terraform workspace new dev
	terraform plan -var-file="dev.hcl"

tf-u-qa:
	aws sso login --profile aws-evershop-qa
	terraform init -upgrade
	terraform workspace select qa || terraform workspace new qa
	terraform plan -var-file="qa.hcl"

tf-u-prod:
	aws sso login --profile aws-evershop-prod
	terraform init -upgrade
	terraform workspace select prod || terraform workspace new prod
	terraform plan -var-file="prod.hcl"

fmt:
	terraform fmt -recursive

validate:
	terraform validate
