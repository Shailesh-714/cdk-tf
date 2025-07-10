notes:

- changing iam policies named kms with appropriate names
- add cluster admin role for users
- should we omit instance types for some node groups
- we are giving excess permissions than neccessary in the kms_policy_document
- should i add eks_node_group security group to cluster or leave it default
- find a way to allow traffic to ext lb (also verify if its correct)
- is adding the ebs csi service account unneccessary as we are attaching the policy to node group role
- remember to inplement the log collection for cloudwatch and s3 bucket
- IMPORTANT: stack name should be in lower and only "-" is allowed
- search for [0] and verify belongs to count or not
- keymanager construct is still pending
- havent added jumpboxes
- why elasticache has public subnets ?
- should i use elasticache replication group instead?

- i am starting to club all the resources needed for a component in same module (important)

- when should sdk build lambda and docker to ecr lambda triggered?

- log-stack.ts is pending (open-search-service)
- add input variables as trigger for encryption lambda
- add labels for istio injection in namespaces

- must handle envoy config for internal load balancer dns name
- there is an auto minor upgrade feature in aws rds cluster, see if we are handling it correctly
- init job containers should have annotations to disable sidecar injection

- revoke all outbound to eks
