# ==========================================================
#                        Network Core
# ==========================================================

# AWS VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-igw"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-nat-gateway-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ==========================================================
#                          Subnets
# ==========================================================

# --->  Public Subnets Group  <---

# Public Subnet
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                     = "${var.stack_name}-public-subnet-${count.index + 1}"
      "kubernetes.io/role/elb" = "1"
      "aws-cdk:subnet-name"    = "public-subnet-1"
      "aws-cdk:subnet-type"    = "Public"
    }
  )
}

# Management Zone Subnets (Public)
resource "aws_subnet" "management_zone" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 12)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-management-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "management-zone"
      "aws-cdk:subnet-type" = "Public"
    }
  )
}

# External Incoming Zone Subnets (Public)
resource "aws_subnet" "external_incoming_zone" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-external-incoming-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "external-incoming-zone"
      "aws-cdk:subnet-type" = "Public"
    }
  )
}

# --->  Private Subnets with Egress Group  <---

# Isolated Subnet (Private with Egress)
resource "aws_subnet" "isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-isolated-subnet-${count.index + 1}"
      "aws-cdk:subnet-name" = "isolated-subnet-1"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Database Isolated Subnets
resource "aws_subnet" "database_isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 4)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-database-isolated-subnet-${count.index + 1}"
      "aws-cdk:subnet-name" = "database-isolated-subnet-1"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# EKS Worker Nodes Subnets (Larger /22 CIDR)
resource "aws_subnet" "eks_worker_nodes" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 6, count.index + 16) # /22 subnet starting at higher offset
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                                      = "${var.stack_name}-eks-worker-nodes-${count.index + 1}"
      "aws-cdk:subnet-name"                     = "eks-worker-nodes-one-zone"
      "aws-cdk:subnet-type"                     = "Private"
      "kubernetes.io/role/internal-elb"         = "1"
      "kubernetes.io/cluster/${var.stack_name}" = "shared"
    }
  )
}

# Utils Zone Subnets
resource "aws_subnet" "utils_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 40)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-utils-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "utils-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Service Layer Zone Subnets
resource "aws_subnet" "service_layer_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 16)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-service-layer-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "service-layer-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Data Stack Zone Subnets
resource "aws_subnet" "data_stack_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 18)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-data-stack-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "data-stack-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Outgoing Proxy LB Zone Subnets
resource "aws_subnet" "outgoing_proxy_lb_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 24)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-outgoing-proxy-lb-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "outgoing-proxy-lb-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Outgoing Proxy Zone Subnets
resource "aws_subnet" "outgoing_proxy_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 26)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-outgoing-proxy-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "outgoing-proxy-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Incoming NPCI Zone Subnets
resource "aws_subnet" "incoming_npci_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 32)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-incoming-npci-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "incoming-npci-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# EKS Control Plane Zone Subnets
resource "aws_subnet" "eks_control_plane_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 34)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-eks-control-plane-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "eks-control-plane-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Incoming Web Envoy Zone Subnets
resource "aws_subnet" "incoming_web_envoy_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 36)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-incoming-web-envoy-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "incoming-web-envoy-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# --->  Private Isolated Subnets Group  <---

# Locker Database Zone Subnets (Isolated)
resource "aws_subnet" "locker_database_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 14)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-locker-database-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "locker-database-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}

# Database Zone Subnets (Isolated)
resource "aws_subnet" "database_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 22)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-database-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "database-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}

# Locker Server Zone Subnets (Isolated)
resource "aws_subnet" "locker_server_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 28)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-locker-server-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "locker-server-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}

# ElastiCache Zone Subnets (Isolated)
resource "aws_subnet" "elasticache_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 30)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-elasticache-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "elasticache-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}

# ==========================================================
#                       Route Tables
# ==========================================================

# Route Tables for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-public-rt"
    }
  )
}

# Route Tables for Private Subnets with NAT
resource "aws_route_table" "private_with_nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-private-nat-rt-${count.index + 1}"
    }
  )
}

# Route Table for Isolated Subnets (no internet access)
resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-isolated-rt"
    }
  )
}

# ==========================================================
#                         Routes
# ==========================================================

# Routes for Public Subnets
resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

# Routes for Private Subnets with NAT
resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  route_table_id         = aws_route_table.private_with_nat[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
}

# ==========================================================
#                 Route Table Associations
# ==========================================================

# --->  Route Table Associations for Public Subnets  <---

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "management_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.management_zone[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "external_incoming_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.external_incoming_zone[count.index].id
  route_table_id = aws_route_table.public.id
}

# --->  Route Table Associations for Private Subnets with NAT  <---

resource "aws_route_table_association" "isolated" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "database_isolated" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database_isolated[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "eks_worker_nodes" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.eks_worker_nodes[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "utils_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.utils_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "service_layer_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.service_layer_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "data_stack_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.data_stack_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "outgoing_proxy_lb_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.outgoing_proxy_lb_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "outgoing_proxy_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.outgoing_proxy_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "incoming_npci_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.incoming_npci_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "eks_control_plane_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.eks_control_plane_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

resource "aws_route_table_association" "incoming_web_envoy_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.incoming_web_envoy_zone[count.index].id
  route_table_id = var.enable_nat_gateway ? aws_route_table.private_with_nat[var.single_nat_gateway ? 0 : count.index].id : aws_route_table.isolated.id
}

# --->  Route Table Associations for Isolated Subnets  <---

resource "aws_route_table_association" "database_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.database_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_route_table_association" "locker_database_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.locker_database_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_route_table_association" "locker_server_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.locker_server_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}

resource "aws_route_table_association" "elasticache_zone" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.elasticache_zone[count.index].id
  route_table_id = aws_route_table.isolated.id
}
