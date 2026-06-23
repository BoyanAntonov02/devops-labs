data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# AWS PRIMARY SERVER
resource "aws_security_group" "web_sg" {
  name = "fincloud-web-sg"
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "primary" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y && yum install -y httpd && systemctl start httpd && systemctl enable httpd
    cat << 'HTML' > /var/www/html/index.html
    <!DOCTYPE html><html><head><meta charset="UTF-8"><title>FinCloud Live</title>
    <style>body{background-color:#0f172a;color:#f8fafc;font-family:Arial;text-align:center;padding-top:100px;}
    .status{color:#3b82f6;font-size:24px;font-weight:bold;margin-bottom:30px;}
    .price{font-size:60px;color:#10b981;font-weight:bold;}</style></head>
    <body>
    <div class="status">🟢 PRIMARY SYSTEM ACTIVE: AWS (Frankfurt)</div>
    <h2>Live Bitcoin (BTC) Price</h2><div class="price" id="btc-price">$ 64,250.00</div>
    <script>setInterval(()=>{document.getElementById('btc-price').innerText = '$ ' + (64000 + Math.random() * 500).toFixed(2);}, 1500);</script>
    </body></html>
    HTML
  EOF
  
  tags = { 
    Name = "FinCloud-Primary" 
  }
}

# GCP SECONDARY SERVER
resource "google_compute_firewall" "default" {
  name    = "fincloud-allow-http"
  network = "default"
  
  allow { 
    protocol = "tcp"
    ports    = ["80"] 
  }
  
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_instance" "secondary" {
  name         = "fincloud-secondary"
  machine_type = "e2-micro"
  zone         = "${var.gcp_region}-a"
  
  boot_disk { 
    initialize_params { 
      image = "debian-cloud/debian-11" 
    } 
  }
  
  network_interface { 
    network = "default"
    access_config {} 
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y apache2 && systemctl start apache2 && systemctl enable apache2
    cat << 'HTML' > /var/www/html/index.html
    <!DOCTYPE html><html><head><meta charset="UTF-8"><title>FinCloud Live</title>
    <style>body{background-color:#0f172a;color:#f8fafc;font-family:Arial;text-align:center;padding-top:100px;}
    .status{color:#f59e0b;font-size:24px;font-weight:bold;margin-bottom:30px;}
    .price{font-size:60px;color:#10b981;font-weight:bold;}</style></head>
    <body>
    <div class="status">🟠 BACKUP SYSTEM ACTIVE: Google Cloud (Frankfurt)</div>
    <h2>Live Bitcoin (BTC) Price</h2><div class="price" id="btc-price">$ 64,250.00</div>
    <script>setInterval(()=>{document.getElementById('btc-price').innerText = '$ ' + (64000 + Math.random() * 500).toFixed(2);}, 1500);</script>
    </body></html>
    HTML
  EOF
}

# ROUTE 53 FAILOVER
resource "aws_route53_health_check" "primary_check" {
  ip_address        = aws_instance.primary.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "primary" {
  zone_id        = var.route53_zone_id
  name           = var.domain_name
  type           = "A"
  ttl            = 60
  set_identifier = "Primary-AWS"
  records        = [aws_instance.primary.public_ip]
  health_check_id = aws_route53_health_check.primary_check.id
  
  failover_routing_policy { 
    type = "PRIMARY" 
  }
}

resource "aws_route53_record" "secondary" {
  zone_id        = var.route53_zone_id
  name           = var.domain_name
  type           = "A"
  ttl            = 60
  set_identifier = "Secondary-GCP"
  records        = [google_compute_instance.secondary.network_interface.0.access_config.0.nat_ip]
  
  failover_routing_policy { 
    type = "SECONDARY" 
  }
}