variable "key" {
    type = string
    default = "cloud_task2_key"
}

variable "security" {
    type = string
    default = "task2_sg"
}

variable "id_vpc" {
    type = string
    default = "vpc-63766a0b"
}

variable "S3" {
    type = string
    default = "t1-s3-bucket"
}

variable "ami_id" {
    type = string
    default = "ami-0b4c18b1c19038d6b"
}

variable "inst_type" {
    type = string
    default = "t2.micro"
}