terraform :

    - aws:
        networking:
            - vpc
            - internet gateway
            - nat-eip
            - nat gateway
            - subnets
            - routes
            - route tables
            - route table associations

        security:
            main:
                security groups:
                    - eks cluster
                    - eks nodes
                    - vpc endpoints
                    - external lb
                    - envoy sg
                    - internal lb
                iam roles:
                    - eks cluster
                    - eks node groups
                    - kms lambda
                iam policies:
                    - eks cluster policy attachment
                    - eks worker node policy attachment
                    - eks cni policy attachment
                    - eks container registry policy attachment
                    - eks cloudwatch policy attachment
                    - eks ec2 readonly policy attachment
                    - eks ebs csi policy attachment
                    - kms lambda encryption policy
                    - eks cloudwatch custom
                kms keys and alias:
                    - hyperswitch kms key
                    - hyperswitch ssm key
                secrets manager:
                    - secretsmanager secret hyperswitch
                    - secretsmanager secret version hyperswitch
            lambda.tf:
                - kms lambda function
                - archive file
                - lambda invocation
                - added the encryption.py
            ssm:
                - all data sources from ssm parameter store

        endpoints:
            - s3
            - ssm
            - ssm messages
            - ec2 messages
            - secrets manager
            - kms
            - rds

        eks:
            main:
                - main cluster
                - eks cloudwatch log group
                - all node groups

            irsa:
                - tls certificate
                - oidc provider
                - hyperswitch service account
                - hyperswitch service account policy
                - hyperswitch service account policy attachment
                - aws load balancer controller irsa
                - kubernetes service account alb controller
                - kubernetes service account ebs csi controller

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
