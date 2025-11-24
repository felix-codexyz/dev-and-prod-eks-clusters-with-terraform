locals {
  clusters = {
    dev = {
      name               = "spztech-DEV"
      vpc_cidr           = "10.0.0.0/16"
      availability_zones = ["us-east-1a", "us-east-1b"]
      node_desired_size  = 3
      node_max_size      = 3
      node_min_size      = 3
      instance_types     = ["t2.large"]
    }
    prod = {
      name               = "spztech-PROD"
      vpc_cidr           = "10.1.0.0/16"
      availability_zones = ["us-east-1c", "us-east-1d"]
      node_desired_size  = 3
      node_max_size      = 3
      node_min_size      = 3
      instance_types     = ["t2.large"]
    }
  }
}

# VPC Resources
resource "aws_vpc" "spztech_vpc" {
  for_each   = local.clusters
  cidr_block = each.value.vpc_cidr

  tags = {
    Name        = "${each.value.name}-vpc"
    Environment = each.key
  }
}

resource "aws_subnet" "spztech_subnet" {
  for_each = {
    for pair in flatten([
      for env, config in local.clusters : [
        for idx in range(2) : {
          key    = "${env}-${idx}"
          env    = env
          idx    = idx
          config = config
        }
      ]
    ]) : pair.key => pair
  }

  vpc_id                  = aws_vpc.spztech_vpc[each.value.env].id
  cidr_block              = cidrsubnet(local.clusters[each.value.env].vpc_cidr, 8, each.value.idx)
  availability_zone       = element(each.value.config.availability_zones, each.value.idx)
  map_public_ip_on_launch = true

  tags = {
    Name        = "${each.value.config.name}-subnet-${each.value.idx}"
    Environment = each.value.env
  }
}

resource "aws_internet_gateway" "spztech_igw" {
  for_each = local.clusters
  vpc_id   = aws_vpc.spztech_vpc[each.key].id

  tags = {
    Name        = "${each.value.name}-igw"
    Environment = each.key
  }
}

resource "aws_route_table" "spztech_route_table" {
  for_each = local.clusters
  vpc_id   = aws_vpc.spztech_vpc[each.key].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.spztech_igw[each.key].id
  }

  tags = {
    Name        = "${each.value.name}-route-table"
    Environment = each.key
  }
}

resource "aws_route_table_association" "a" {
  for_each = {
    for pair in flatten([
      for env, config in local.clusters : [
        for idx in range(2) : {
          key = "${env}-${idx}"
          env = env
        }
      ]
    ]) : pair.key => pair
  }

  subnet_id      = aws_subnet.spztech_subnet[each.key].id
  route_table_id = aws_route_table.spztech_route_table[each.value.env].id
}

resource "aws_security_group" "spztech_cluster_sg" {
  for_each = local.clusters
  vpc_id   = aws_vpc.spztech_vpc[each.key].id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${each.value.name}-cluster-sg"
    Environment = each.key
  }
}

resource "aws_security_group" "spztech_node_sg" {
  for_each = local.clusters
  vpc_id   = aws_vpc.spztech_vpc[each.key].id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${each.value.name}-node-sg"
    Environment = each.key
  }
}

resource "aws_eks_cluster" "spztech" {
  for_each = local.clusters
  name     = each.value.name
  role_arn = aws_iam_role.spztech_cluster_role[each.key].arn

  vpc_config {
    subnet_ids = [
      for idx in range(2) : aws_subnet.spztech_subnet["${each.key}-${idx}"].id
    ]
    security_group_ids = [aws_security_group.spztech_cluster_sg[each.key].id]
  }

  tags = {
    Environment = each.key
  }
}

resource "aws_eks_node_group" "spztech" {
  for_each        = local.clusters
  cluster_name    = aws_eks_cluster.spztech[each.key].name
  node_group_name = "${each.value.name}-node-group"
  node_role_arn   = aws_iam_role.spztech_node_group_role[each.key].arn
  subnet_ids = [
    for idx in range(2) : aws_subnet.spztech_subnet["${each.key}-${idx}"].id
  ]

  scaling_config {
    desired_size = each.value.node_desired_size
    max_size     = each.value.node_max_size
    min_size     = each.value.node_min_size
  }

  instance_types = each.value.instance_types

  remote_access {
    ec2_ssh_key               = var.ssh_key_name
    source_security_group_ids = [aws_security_group.spztech_node_sg[each.key].id]
  }

  tags = {
    Environment = each.key
  }
}

# IAM Roles
resource "aws_iam_role" "spztech_cluster_role" {
  for_each = local.clusters
  name     = "${each.value.name}-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Environment = each.key
  }
}

resource "aws_iam_role_policy_attachment" "spztech_cluster_role_policy" {
  for_each   = local.clusters
  role       = aws_iam_role.spztech_cluster_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "spztech_node_group_role" {
  for_each = local.clusters
  name     = "${each.value.name}-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    Environment = each.key
  }
}

resource "aws_iam_role_policy_attachment" "spztech_node_group_role_policy" {
  for_each   = local.clusters
  role       = aws_iam_role.spztech_node_group_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "spztech_node_group_cni_policy" {
  for_each   = local.clusters
  role       = aws_iam_role.spztech_node_group_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "spztech_node_group_registry_policy" {
  for_each   = local.clusters
  role       = aws_iam_role.spztech_node_group_role[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
