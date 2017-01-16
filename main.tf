resource "aws_vpc" "default" {
    cidr_block = "${var.vpc_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "example-1-vpc"
    }
}

resource "aws_internet_gateway" "default"{
	vpc_id = "${aws_vpc.default.id}"
}

resource "aws_subnet" "us-west-2a-public" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.public_subnet_cidr}"
    availability_zone = "us-west-2a"

    tags {
        Name = "Public Subnet exmpl-1"
    }
}

resource "aws_subnet" "us-west-2a-private" {
    vpc_id = "${aws_vpc.default.id}"

    cidr_block = "${var.private_subnet_cidr}"
    availability_zone = "us-west-2a"

    tags {
        Name = "Private Subnet exmpl-1"
    }
}

resource "aws_route_table" "us-west-2a-public"{
	vpc_id = "${aws_vpc.default.id}"
	
	route{
		cidr_block = "0.0.0.0/0"
		gateway_id = "${aws_internet_gateway.default.id}"
	}

	tags{
		Name = "route-table-1"
	}
}

resource "aws_route_table_association" "us-west-2a-public" {
    subnet_id = "${aws_subnet.us-west-2a-public.id}"
    route_table_id = "${aws_route_table.us-west-2a-public.id}"
}

resource "aws_route_table_association" "us-west-2a-private" {
    subnet_id = "${aws_subnet.us-west-2a-private.id}"
    route_table_id = "${aws_route_table.us-west-2a-public.id}"
}

resource "aws_security_group" "sg-bastion-host" {
    name = "vpc_sg-bastion-host"
    description = "Allow traffic to pass to the public subnet from the internet"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    vpc_id = "${aws_vpc.default.id}"

    tags {
        Name = "terraform-sg-bastion-host"
    }
}

resource "aws_security_group" "sg-App-server" {
    name = "vpc_sg-App-server"
    description = "Allow traffic to pass to the public subnet from the internet"
   
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.public_subnet_cidr}"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    vpc_id = "${aws_vpc.default.id}"

    tags {
        Name = "terraform-sg-App-server"
    }
}

resource "aws_security_group" "sg-DB-server" {
    name = "vpc_sg-DB-server"
    description = "Allow traffic to pass to the public subnet from the internet"
   
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["${var.private_subnet_cidr}"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = -1
        cidr_blocks = ["0.0.0.0/0"]
    }
    vpc_id = "${aws_vpc.default.id}"

    tags {
        Name = "terraform-sg-DB-server"
    }
}

resource "aws_instance" "bastion-host" {
  ami           = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.sg-bastion-host.id}"]
  subnet_id = "${aws_subnet.us-west-2a-public.id}"
  associate_public_ip_address = true
  source_dest_check = false

  tags {
      Name = "terraform-bastion-host "
  }



	provisioner "file" {
		connection {
		    type = "ssh"
		    user = "ec2-user"
		    private_key = "${file("/home/kuldeep/Downloads/kuldeep-key-1.pem")}"
		    agent = false
		    timeout = "2m"
		}
		source = "/home/kuldeep/Downloads/kuldeep-key-2.pem"
		destination = "/home/ec2-user/kuldeep-key-2.pem"
	}

  provisioner "file" {
    connection {
        type = "ssh"
        user = "ec2-user"
        private_key = "${file("/home/kuldeep/Downloads/kuldeep-key-1.pem")}"
        agent = false
        timeout = "2m"
    }
    source = "/home/kuldeep/Documents/workspace/kuldeep/rails_application/event_scheduler"
    destination = "/home/ec2-user/event_scheduler"
  }

	provisioner "remote-exec" {
		connection {
		    type = "ssh"
		    user = "ec2-user"
		    private_key = "${file("/home/kuldeep/Downloads/kuldeep-key-1.pem")}"
		    agent = false
		    timeout = "2m"
		}
		inline = [
		  "chmod 400 kuldeep-key-2.pem",
      
		  "ssh -i \"kuldeep-key-2.pem\" -o StrictHostKeyChecking=no -l ec2-user 10.0.1.10 \"sudo yum install httpd -y; sudo service httpd start; sudo yum install -y git-core zlib zlib-devel gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel; git clone git://github.com/sstephenson/rbenv.git .rbenv; echo 'export PATH=\"$HOME/.rbenv/bin:$PATH\"' >> ~/.bashrc; echo 'eval \"$(rbenv init -)\"' >> ~/.bashrc; exec $SHELL; git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build; echo 'export PATH=\"$HOME/.rbenv/plugins/ruby-build/bin:$PATH\"' >> ~/.bashrc; exec $SHELL; rbenv install -v 2.2.1; rbenv global 2.2.1; echo \"gem: --no-document\" > ~/.gemrc; gem install bundler; gem install rails; rbenv rehash; sudo yum -y install epel-release; sudo yum install nodejs\" "
          
        ]	
	}
}

resource "aws_instance" "App-server" {
  ami           = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name-2}"
  vpc_security_group_ids = ["${aws_security_group.sg-App-server.id}"]
  subnet_id = "${aws_subnet.us-west-2a-private.id}"
  associate_public_ip_address = true
  private_ip = "${var.private-ip}"
  source_dest_check = false

  tags {
      Name = "terraform-App-server "
  }
}

resource "aws_instance" "DB-server" {
  ami           = "${lookup(var.amis, var.aws_region)}"
  instance_type = "t2.micro"
  key_name = "${var.aws_key_name}"
  vpc_security_group_ids = ["${aws_security_group.sg-DB-server.id}"]
  subnet_id = "${aws_subnet.us-west-2a-private.id}"
  associate_public_ip_address = true
  source_dest_check = false

  tags {
      Name = "terraform-DB-server"
  }
}
