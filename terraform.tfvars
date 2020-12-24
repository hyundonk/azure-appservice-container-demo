# input variables 

prefix                = "demo"
resource_group_name   = "DEMORG"
location              = "koreacentral"

networking_object                 = {
  vnet = {
      name                = "-test-vnet"
      address_space       = ["10.10.0.0/16"]
      dns                 = []
  }
  specialsubnets = {
  }

  subnets = {
   frontend   = {
      name                = "frontend"
      cidr                = "10.10.0.0/24"
      service_endpoints   = []
      nsg_name            = "frontend"
    },
    backend   = {
      name                = "backend"
      cidr                = "10.10.1.0/24"
      service_endpoints   = []
      nsg_name            = "backend"
    },
    appgateway   = {
      name                = "appgateway"
      cidr                = "10.10.2.0/24"
      service_endpoints   = []
      nsg_name            = "appgateway"
    }
  }
}

certificates = {
  0               = {
    name      = "sslcert01"
    filepath  = "./sslcert01.pfx"
    password  = "Azure123456!"
  }
}

acr_username = "myacrusername"
acr_password = "myacrpassword"
