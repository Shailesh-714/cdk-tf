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
            security groups:
                - eks cluster
                - eks nodes
                - alb
                - vpc endpoints
            iam roles:
                - eks cluster
                - eks node groups
            iam policies:
            iam role-policies(inline):
                - eks cloudwatch custom
            iam role policy attachments:
                - eks cluster policy attachment
                - eks worker node policy attachment
                - eks cni policy attachment
                - eks container registry policy attachment
                - eks cloudwatch policy attachment
                - eks ec2 readonly policy attachment
                - eks ebs csi policy attachment
            kms keys and alias:
                - hyperswitch kms key
                - hyperswitch ssm key

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

notes:

- changing iam policies named kms with appropriate names
- add cluster admin role for users
- should we omit instance types for some node groups
- we are giving excess permissions than neccessary in the kms_policy_document
