vega_binary_path = "vega"

network "testnet" {
	ethereum {
    chain_id   = "1440"
    network_id = "1441"
    endpoint   = "ws://127.0.0.1:8545/"
  }
  secondary_ethereum {
    chain_id   = "1450"
    network_id = "1451"
    endpoint   = "ws://127.0.0.1:8546/"
  }
  faucet "faucet-1" {
	  wallet_pass = "f4uc3tw4ll3t-v3g4-p4ssphr4e3"

	  template = <<-EOT
[RateLimit]
  CoolDown = "1ns"
  AllowList = ["0.0.0.0/0", "192.0.0.0/24", "127.0.0.0/24"]

[Node]
  Port = 3002
  IP = "127.0.0.1"
EOT
  }

  wallet "wallet-1" {
    token_passphrase_path = "password.txt"
    template = <<-EOT
Name = "DV"
Level = "info"
TokenExpiry = "168h0m0s"
Port = 1789
Host = "0.0.0.0"

[API]
  [API.GRPC]
    Hosts = [{{range $i, $v := .Validators}}{{if ne $i 0}},{{end}}"127.0.0.1:{{add 300 $i}}2"{{end}}]
    Retries = 5
EOT
  }

  pre_start {
    docker_service "ganache-1" {
      # Do not use the `latest` tag to avoid pulling image every network restart.
      image = "vegaprotocol/ganache:v1.6.0"
      args  = [
        "--miner.blockTime", "1",
        "--chain.chainId", "1440",
        "--chain.networkId", "1441",
        "-h", "0.0.0.0",
        "-p", "8545",
        "--wallet.mnemonic", "ozone access unlock valid olympic save include omit supply green clown session",
        "--database.dbPath", "/app/ganache-db",
        "--wallet.accountKeysPath", "keys.json"
      ]
      resources {
        cpu        = 500
        memory     = 1024
        memory_max = 2048
        disk       = 1024
      }
      static_port {
        value = 8545
        to = 8545
      }
      auth_soft_fail = true
    }
    docker_service "ganache-2" {
      image = "vegaprotocol/ganache:v1.6.0"
      args  = [
        "--miner.blockTime", "1",
        "--chain.chainId", "1450",
        "--chain.networkId", "1451",
        "-h", "0.0.0.0",
        "-p", "8546",
        "--wallet.mnemonic", "ozone access unlock valid olympic save include omit supply green clown session",
        "--database.dbPath", "/app/ganache-db",
        "--wallet.accountKeysPath", "keys.json"
      ]
      resources {
        cpu        = 500
        memory     = 1024
        memory_max = 2048
        disk       = 1024
      }
      static_port {
        value = 8546
        to    = 8546
      }
      auth_soft_fail = true
    }

    docker_service "postgres-1" {
      image = "vegaprotocol/timescaledb:2.8.0-pg14"
      cmd = "postgres"
      args = []
      env = {
        POSTGRES_USER="vega"
        POSTGRES_PASSWORD="vega"
        POSTGRES_DBS="vega0,vega1,vega2,vega3,vega4,vega5,vega6,vega7,vega8,vega9,vega10,vega11,vega12,vega13,vega14,vega15,vega16,vega17,vega18,vega19,vega20,vega21,vega22,vega23,vega24,vega25"
      }
      
      static_port {
        value = 5232
        to = 5432
      }
      resources {
        cpu = 600
        memory = 9000
      }
      
      volume_mounts = ["${network_home_path}:${network_home_path}"]

      auth_soft_fail = true
    }
  }
  
  genesis_template_file = "./genesis.tmpl"
  smart_contracts_addresses_file = "./public_smart_contracts_addresses.json"
  secondary_smart_contracts_addresses_file = "./secondary_public_smart_contracts_addresses.json"

  node_set "validators" {
    count = 2
    mode = "validator"
  
    node_wallet_pass = "n0d3w4ll3t-p4ssphr4e3"
    vega_wallet_pass = "w4ll3t-p4ssphr4e3"
    ethereum_wallet_pass = "ch41nw4ll3t-3th3r3um-p4ssphr4e3"
    
    config_templates {
      vega_file = "./vega_validators.tmpl"
      tendermint_file = "./tendermint_validators.tmpl"
    }
  }

  node_set "full" {
    count = 1
    mode = "full"
    use_data_node = true
    
    pre_start_probe {
      postgres {
        connection = "user=vega dbname=vega{{ .NodeNumber }} password=vega port=5232 sslmode=disable"
        query = "select 10 + 10"
      }
    }

    config_templates {
      vega_file = "./vega_full.tmpl"
      tendermint_file = "./tendermint_full.tmpl"
      data_node_file = "./data_node_full_external_postgres.tmpl"
    }
  }
}
