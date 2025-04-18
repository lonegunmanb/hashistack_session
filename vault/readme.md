# HashiCorp Vault 动态机密演示

许多组织将凭据硬编码在源代码中，散布在配置文件和配置管理工具中，并以明文形式存储在版本控制、wiki 和共享卷中。 保护和确保凭证不被泄露，或者在可能的情况下，组织可以快速撤销访问权限并进行补救，是一个需要解决的复杂问题。

动态秘密是根据需要生成的，并且对于客户端来说是唯一的，而不是提前定义并共享的静态秘密。 Vault 将每个动态机密与租约相关联，并在租约到期时自动销毁凭据。 Vault 支持各种系统的动态机密，并且可以通过插件轻松扩展。

本样例为大家简要演示一个通过动态机密管理数据库账户以及应用程序的配置文件的[例子](vault.md)。

编译 pdf 命令：

```shell
docker run -v $(pwd):/src -w /src marpteam/marp-cli --pdf vault.md
```

Windows 下：

```shell
docker run -v ${pwd}:/src -w /src marpteam/marp-cli --pdf vault.md
```
