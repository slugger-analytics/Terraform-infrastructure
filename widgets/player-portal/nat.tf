# NAT Gateway for Sync Lambda Internet Access
#
# The player-portal-sync Lambda needs to reach thebaseballcube.com (TBC) feeds.
# TBC/Cloudflare blocks AWS Lambda IP ranges, so we need a fixed Elastic IP
# that can be whitelisted by TBC.
#
# Architecture:
#   sync Lambda → private subnet (172.30.10.0/24) → NAT Gateway → Elastic IP → internet
#
# After applying, email TBC (support@thebaseballcube.com) with the Elastic IP
# from the `nat_elastic_ip` output and ask them to whitelist it for feed access.

# ─── Elastic IP for the NAT Gateway ──────────────────────────────────────────

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(local.tags, { Name = "player-portal-nat-eip" })
}

# ─── NAT Gateway (in an existing public subnet) ───────────────────────────────

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = "subnet-00b1945e1c7f15475" # us-east-2a public subnet (has IGW route)

  tags       = merge(local.tags, { Name = "player-portal-nat" })
  depends_on = [aws_eip.nat]
}

# ─── True Private Subnet (routes outbound through NAT, not IGW) ───────────────

resource "aws_subnet" "sync_private" {
  vpc_id                  = data.aws_vpc.main.id
  cidr_block              = "172.30.10.0/24"
  availability_zone       = "us-east-2a"
  map_public_ip_on_launch = false

  tags = merge(local.tags, {
    Name = "player-portal-sync-private-2a"
    Type = "private-nat"
  })
}

# ─── Route Table: private subnet → NAT Gateway ───────────────────────────────

resource "aws_route_table" "sync_private" {
  vpc_id = data.aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.tags, { Name = "player-portal-sync-rt" })
}

resource "aws_route_table_association" "sync_private" {
  subnet_id      = aws_subnet.sync_private.id
  route_table_id = aws_route_table.sync_private.id
}
