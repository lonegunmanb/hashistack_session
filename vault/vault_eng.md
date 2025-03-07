---
marp: true

theme: gaia
paginate: true
---

# Managing Dynamic Secrets with HashiCorp Vault

---

# Secrets Sprawl

In traditional R&D scenarios, we often encounter issues such as: production database usernames and passwords being encoded in configuration files in plain text, or stored in an unsecured configuration management service in the production environment; tokens used by an application to call cloud service interfaces being hardcoded into the code and then accidentally leaked by a developer to a public GitHub repository, and so on.

---

Secrets sprawl describes such issues, where system secrets are scattered and stored in various unrelated locations in different forms. We neither know which systems store which secrets, nor which secrets have been accessed by which systems and people. Even if we discover that a secret has been leaked, we cannot be sure that immediately revoking the secret from the production environment will not jeopardize production environment, because we do not know which systems are still using these secrets.

---

# HashiCorp Vault

In our daily work, we deal with a lot of secret information inevitably. In the past, we often faced the following problems in our work:
* Exercising password rotation policies is painful
* Employees who know the secrets may leak them on purpose or take malicious actions after leaving the company
* Developers accidentally leak secrets to public source code repositories on the Internet along with the code
* Managing secrets for multiple systems is very troublesome, and cumbersome

---

# Vault Architecture

![width:900px](https://raw.githubusercontent.com/lonegunmanb/essential-vault-pic/main/1616989467747-image.png)

---

# Vault Plugins Ecosystem

* Secret Engine: the component Vault uses to store secrets or perform encryption and decryption.
* Auth Method: the component Vault uses to implement Vault user authentication.

The combination of the two builds a rich ecosystem.

---


![width:750px](https://developer.hashicorp.com/_next/image?url=https%3A%2F%2Fcontent.hashicorp.com%2Fapi%2Fassets%3Fproduct%3Dtutorials%26version%3Dmain%26asset%3Dpublic%252Fimg%252Fvault%252Fvault-triangle.png%26width%3D1641%26height%3D973&w=1920&q=75)

---

# A Simple Example

We will use Docker to start a Postgres database locally, simulating a production environment service.

Then use the testing version of the Vault service to manage its account permissions.

Then simulate a real application accessing the Vault service to read a set of dynamic usernames and passwords.

---

# Roles in the Experiment

* `admin`: Administrator with Vault and database administrator privileges.
* `app`: Application that reads dynamic database credentials from Vault.

---

# Start Postgres

We use Docker to start a Postgres database instance with username `root` and password `rootpassword`(**DO NOT DO THIS IN YOUR PRODUCTION ENVIRONMENT**):

```shell
sudo docker run \
-d \
--name learn-postgres \
-e POSTGRES_USER=root \
-e POSTGRES_PASSWORD=rootpassword \
-p 5432:5432 \
--rm \
postgres
```

---

Create a database role named `ro`:

```shell
sudo docker exec -i \
learn-postgres \
psql -U root -c "CREATE ROLE \"ro\" NOINHERIT;"
```

Grant read permission on all tables to `ro` role:

```shell
sudo docker exec -i \
learn-postgres \
psql -U root -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"ro\";"
```

---

# Start Vault

We start Vault service in a `-dev` mode, using `root` as the root token:

```shell
vault server -dev -dev-root-token-id root
```

---

# Enable Database Secret Engine

Operator: `admin`

Set environment variables

```shell
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
```

Enable database secret engine:

```shell
vault secrets enable database
```

---

# Configure PostgreSQL Secret Engine

Operator: `admin`

Configure the Postgres connection credentials used via the command:

```shell
vault write database/config/postgresql \
plugin_name=postgresql-database-plugin \
connection_url="postgresql://{{username}}:{{password}}@localhost:5432/postgres?sslmode=disable" \
allowed_roles=readonly \
username="root" \
password="rootpassword"
```

---

Note that since `ssl` is not enabled for the database in this experiment, `?sslmode=disable` is specifically added to the end of the `connection_url` connection string. **Do not do this in a production system**.

---

# Create Database Role

Operator: `admin`

Define the SQL statement used to create credentials:

```shell
tee readonly.sql <<EOF
        CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT;
GRANT ro TO "{{name}}";
EOF
```

---

The SQL statement contains templated fields `{{name}}`, `{{password}}` and `{{expiration}}`. These fields are populated when Vault creates credentials.

This will create a new role and grant the privileges of the role named `ro` that was previously created in Postgres to it.

---

We use the following command to create a role named `readonly` that creates credentials using the contents of the `readonly.sql` file:

```shell
vault write database/roles/readonly \
db_name=postgresql \
creation_statements=@readonly.sql \
default_ttl=1h \
max_ttl=24h
```

---

# Create Vault Permissions for `app` User

Operator: `admin`

```shell
vault policy write app -<<EOF
        path "database/creds/readonly" {
capabilities = [ "read" ]
}
EOF
```

---

# Create Vault Token for `app` User

Operator: `admin`

```shell
vault token create -policy=app
```

---

# Set Environment Variables for `app` operator

```shell
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<token>
```

---

# Read Postgres Credentials

Operator: `app`

```shell
vault read database/creds/readonly
```

Test the connection to the Postgres database by listing all database users:

```shell
sudo docker exec -i \
learn-postgres \
psql -U <username> -d postgres -c "SELECT usename, valuntil FROM pg_user;"
```

---

# Lease Management

Operator: `admin`

All credentials created by Vault are associated with corresponding lease IDs. Credentials are valid until their TTL expires or they are revoked. Once a lease is revoked, the credentials also become invalid.

List existing leases:

```shell
vault list sys/leases/lookup/database/creds/readonly
```

---

Save lease id：

```shell
LEASE_ID=$(vault list -format=json sys/leases/lookup/database/creds/readonly | jq -r ".[0]")
```

---

# Renew

Operator: `admin`

View lease:

```shell
vault lease lookup database/creds/readonly/$LEASE_ID
```

Renew lease and corresponding database credential by using lease id:

```shell
vault lease renew database/creds/readonly/$LEASE_ID
```

---

# Revoke Lease

Operator: `admin`

Revoke lease before it expires:

```shell
vault lease revoke database/creds/readonly/$LEASE_ID
```

List existing leases again:

```shell
vault list sys/leases/lookup/database/creds/readonly
```

---

Verify Database User Has Been Deleted

```shell
sudo docker exec -i learn-postgres psql -U root -c "SELECT usename, valuntil FROM pg_user;"
```

---

# Consul-Template

[Consul-Template](https://github.com/hashicorp/consul-template) is a command-line tool developed by HashiCorp to render data from HashiCorp Consul, Vault, or Nomad into text files.

Installation:

```shell
go install github.com/hashicorp/consul-template@latest
```

---

# Application Scenario

Assume our application needs to read secrets from a configuration file.

First, let's shorten the default ttl(time to live) of the lease.

Operator: `admin`

```shell
vault write database/roles/readonly \
      db_name=postgresql \
      creation_statements=@readonly.sql \
      default_ttl=30s \
      max_ttl=24h
```

---

# Application Config Template

Save as `config.toml.tplt`
```shell
cat <<EOF > config.toml.tplt
[database]
host = "localhost"
port = 5432
{{ with secret "database/creds/readonly" }}
username = "{{ .Data.username }}"
password = "{{ .Data.password }}"
{{ end }}
EOF
```

---

# Consul-Template's config

Save as `ct_config.hcl`：

```hcl
cat <<EOF > ct_config.hcl
vault {
  address = "http://127.0.0.1:8200"
  renew_token = true
  default_lease_duration = "60s"
  lease_renewal_threshold = 0.5
}
EOF
```

---

# Start Consul-Template

Operator：`app`

```shell
consul-template -template "config.toml.tplt:config.toml" -config "ct_config.hcl"
```

---

# Lookup lease's ttl

```shell
vault list sys/leases/lookup/database/creds/readonly
LEASE_ID=$(vault list -format=json sys/leases/lookup/database/creds/readonly | jq -r ".[0]")
vault lease lookup database/creds/readonly/$LEASE_ID
```