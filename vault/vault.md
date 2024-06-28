---
marp: true

theme: gaia
paginate: true
---

# 利用 HashiCorp Vault 管理动态机密

---

# 机密蔓生

在传统的研发场景中我们经常能够看到这样的问题：生产环境的数据库用户名密码被以明文形式编码在配置文件中，或是保存在生产环境中某个不设防的配置管理服务中；某个应用调用云服务接口所用的令牌被硬编码在代码里，随后不小心被程序员上传到一个公共的 Github 仓库中等等。

机密蔓生描述的就是这样的问题，系统机密信息被零散地以不同形式保存在许多彼此不相关的地方，我们即不知道哪些系统保存了哪些机密，也不知道哪些机密被哪些系统哪些人获取了。即使我们发现某个机密信息流失在外，也无法确信立即从生产环境中吊销该机密不会导致生产环境的故障，因为我们不知道哪些系统正在使用这些机密。

---

# HashiCorp Vault

简单来说，在我们日常的工作中，免不了要和许多的机密信息打交道。以往在工作中我们经常面临着这样的问题：
* 执行密码轮换策略很痛苦
* 掌握机密的员工离职后可能泄密或是恶意报复
* 开发者不小心把机密信息随着代码上传到公网的源码仓库造成泄密
* 管理多个系统的机密非常麻烦
* 需要将机密信息安全地加密后存储，但又不想将密钥暴露给应用程序，以防止应用程序被入侵后连带密钥一起泄漏

---

# Vault 架构

![width:900px](https://raw.githubusercontent.com/lonegunmanb/essential-vault-pic/main/1616989467747-image.png)

---

# Vault 插件生态

Secret Engine 是 Vault 用来存储机密，或是执行加解密的组件。
Auth Method 是 Vault 用来实现 Vault 用户身份认证的组件
二者相结合，构建了丰富的生态体系

![width:750px](https://developer.hashicorp.com/_next/image?url=https%3A%2F%2Fcontent.hashicorp.com%2Fapi%2Fassets%3Fproduct%3Dtutorials%26version%3Dmain%26asset%3Dpublic%252Fimg%252Fvault%252Fvault-triangle.png%26width%3D1641%26height%3D973&w=1920&q=75)

# 两个简单的例子

我们将以 Docker 在本地启动 Postgres 数据库和 Redis，模拟生产环境服务

然后使用测试版本 Vault 服务管理它的账号权限

然后模拟真实应用访问 Vault 服务，读取一组动态的用户名密码

---

# 参与实验的角色

* `admin`：拥有 Vault 以及数据库管理员特权的管理员
* `app`：从 Vault 读取数据库动态凭据的应用程序

---

# 启动 Postgres

我们使用 Docker 启动一个用户名为 `root`，密码为 `rootpassword` 的 Postgres 数据库实例：

```shell
docker run \
    -d \
    --name learn-postgres \
    -e POSTGRES_USER=root \
    -e POSTGRES_PASSWORD=rootpassword \
    -p 5432:5432 \
    --rm \
    postgres
```

---

创建一个名为 ro 的数据库角色：

```shell
docker exec -i \
    learn-postgres \
    psql -U root -c "CREATE ROLE \"ro\" NOINHERIT;"
```

赋予角色 ro 读取所有表的权限：

```shell
docker exec -i \
    learn-postgres \
    psql -U root -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"ro\";"
```

---

# 启动 Vault

我们在新的命令行终端中启动一个 `-dev` 模式的 Vault 服务，使用 `root` 作为根令牌：

```shell
vault server -dev -dev-root-token-id root
```

---

# 启用数据库机密引擎

操作者：`admin`

设置环境变量

```shell
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=root
```

启用数据库机密引擎

```shell
vault secrets enable database
```

---

# 配置 PostgreSQL 机密引擎

操作者：`admin`

通过命令行配置使用的 Postgres 连接凭据：

```shell
vault write database/config/postgresql \
     plugin_name=postgresql-database-plugin \
     connection_url="postgresql://{{username}}:{{password}}@localhost:5432/postgres?sslmode=disable" \
     allowed_roles=readonly \
     username="root" \
     password="rootpassword"
```

要注意的是，由于本实验中没有为数据库启用 `ssl`，所以在 `connection_url` 连接字符串的末尾特意加上了 `?sslmode=disable`。**请不要在生产环境这样做**。

---

# 创建数据库角色

操作者：`admin`

定义用来创建凭据的 SQL 语句：

```shell
tee readonly.sql <<EOF
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' INHERIT;
GRANT ro TO "{{name}}";
EOF
```

SQL 语句包含了模板化的字段 {{name}}、{{password}} 以及 {{expiration}}。这些字段会在 Vault 创建凭据时被填充。这将创建一个新角色，并将先前在 Postgres 中创建的名为 `ro` 的角色拥有的权限赋予这个新角色。

---

我们用以下命令来创建使用 `readonly.sql` 文件的内容创建凭据的名为 `readonly` 的角色：

```shell
vault write database/roles/readonly \
      db_name=postgresql \
      creation_statements=@readonly.sql \
      default_ttl=1h \
      max_ttl=24h
```
---

# 为 `app` 用户创建 Vault 权限

操作者：`admin`

```shell
vault policy write app -<<EOF
path "database/creds/readonly" {
  capabilities = [ "read" ]
}
EOF
```

---

# 为 `app` 用户创建 Vault Token

操作者：`admin`

```shell
vault token create -policy=app
```

---

# 设置 `app` 环境变量

操作者：`admin`

设置环境变量

```shell
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=<token>
```

---

请求 Postgres 凭据

操作者：`app`

```shell
vault read database/creds/readonly
```

验证

连接到 Postgres 数据库，列出所有数据库用户：

```shell
docker exec -i \
    learn-postgres \
    psql -U root -c "SELECT usename, valuntil FROM pg_user;"
```

---

# 管理租约

操作者：`admin`

Vault 创建的所有凭据都关联了对应的租约 ID，在 TTL 到期前或是被吊销前凭据有效。一旦租约被吊销，则凭据也将不再有效。

列出存在的租约：

```shell
vault list sys/leases/lookup/database/creds/readonly
```

保存租约 ID：

```shell
LEASE_ID=$(vault list -format=json sys/leases/lookup/database/creds/readonly | jq -r ".[0]")
```

---

# 续约

操作者：`admin`

查看租约：

```shell
vault lease lookup database/creds/readonly/$LEASE_ID
```

传递租约 ID 续约租约及相应的数据库凭据：

```shell
vault lease renew database/creds/readonly/$LEASE_ID
```

---

# 吊销租约

操作者：`admin`

在租约过期前吊销租约：

```shell
vault lease revoke database/creds/readonly/$LEASE_ID
```

尝试再列出存在的租约：

```shell
vault list sys/leases/lookup/database/creds/readonly
```

---

# Consul-Template

[Consul-Template](https://github.com/hashicorp/consul-template) 是 HashiCorp 开发的命令行工具，用以将 HashiCorp Consul、Vault 或是 Nomad 中的数据渲染成文本文件

安装：

```shell
go install github.com/hashicorp/consul-template@v0.39.0
```

---

# 假设场景

假设我们的应用程序需要从配置文件读取机密

首先，我们先缩短租约的默认有效时长

操作者：`admin`

```shell
vault write database/roles/readonly \
      db_name=postgresql \
      creation_statements=@readonly.sql \
      default_ttl=1m \
      max_ttl=24h
```

---

# 配置文件模板

保存为 `config.toml.tplt`
```toml
[database]
host = "localhost"
port = 5432
{{ with secret "database/creds/readonly" }}
username = "{{ .Data.username }}"
password = "{{ .Data.password }}"
{{ end }}
```

---

# Consul-Template 模板

保存为 `ct_config.hcl`：

```hcl
vault {
  address = "http://127.0.0.1:8200"
  renew_token = true
  default_lease_duration = "60s"
  lease_renewal_threshold = 0.5
}
```

---

# 启动 Consul-Template

操作者：`app`

```shell
consul-template -template "config.toml.tplt:config.toml" -config "ct_config.hcl"
```

---

# 观察租约有效期

```shell
vault list sys/leases/lookup/database/creds/readonly
vault lease lookup database/creds/readonly/<lease_id>
```

---

# 启动 redis

```shell
docker run --name redis -d -p 6379:6379 redis
docker run -it --rm --network=host redis redis-cli
ACL SETUSER user
ACL SETUSER user on >pass ~* &* +@all
```

---

# 写入 Redis 配置

操作者：`admin`

```shell
vault write database/config/my-redis-database \
  plugin_name="redis-database-plugin" \
  host="localhost" \
  port=6379 \
  username=user \
  password="pass" \
  allowed_roles="my-*-role"
vault write -force database/rotate-root/my-redis-database
```

---

# 新增 Redis Role

操作者：`admin`

```shell
vault write database/roles/my-dynamic-role \
    db_name="my-redis-database" \
    creation_statements='["+@admin"]' \
    default_ttl="1m" \
    max_ttl="1h"
```

```shell
vault policy write redis -<<EOF
path "database/creds/my-dynamic-role" {
  capabilities = [ "read" ]
}
EOF
```

---

# 创建用来连接 Redis 的 Vault Token

操作者：`admin`

```shell
vault token create -policy=redis
```

---

# 尝试读取 Redis 凭据

操作者：`app`

```shell
vault read database/creds/my-dynamic-role
```