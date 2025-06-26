---
marp: true

theme: gaia
paginate: true
---

# 2025/06/27 Terraform 交流

---

# 1. Terraform Module 企业级最佳实践

说实话，我对 Terraform Module 在企业中的最佳实践并没有太多的经验，但对于这里提到的一些问题，我有一些自己的看法。

---

# 模块设计：如何平衡参数化（灵活性）与合规性（硬编码关键配置）？

[Azure Verified Modules](https://aka.ms/avm) 是微软推出的官方开源项目，旨在为基础设施即代码（Infrastructure as Code，IaC）模块建立统一标准，提升 Azure 资源部署的一致性、可靠性和可维护性。

AVM 将模块分成三种大类：

[资源模块(Resource Module)](https://lonegunmanb.github.io/dao-of-terraform-modules/%E5%A6%82%E4%BD%95%E8%AE%BE%E8%AE%A1%E4%B8%80%E4%B8%AATerraform%E6%A8%A1%E5%9D%97/%E8%B5%84%E6%BA%90%E6%A8%A1%E5%9D%97.html)
[模式模块(Pattern Module)](https://lonegunmanb.github.io/dao-of-terraform-modules/%E5%A6%82%E4%BD%95%E8%AE%BE%E8%AE%A1%E4%B8%80%E4%B8%AATerraform%E6%A8%A1%E5%9D%97/%E6%A8%A1%E5%BC%8F%E6%A8%A1%E5%9D%97.html)
[工具模块(Utility Module)](https://lonegunmanb.github.io/dao-of-terraform-modules/%E5%A6%82%E4%BD%95%E8%AE%BE%E8%AE%A1%E4%B8%80%E4%B8%AATerraform%E6%A8%A1%E5%9D%97/%E5%B7%A5%E5%85%B7%E6%A8%A1%E5%9D%97.html)

---

# 最大的灵活性 —— 资源模块

Resource Module 尽可能将资源 Schema 中定义的所有可配置参数都以输入变量的形式暴露出来，供使用者配置。

优点：最大化的灵活性。
缺点：使用者需要了解 Azure 资源的 Schema，才能正确配置。不少使用者抱怨 AVM 的资源模块过于复杂，配置起来很麻烦。

---

# 开箱即用的便利性 —— 模式模块

Pattern Module 预先构想了某种特定的使用场景，并且预置了关键的配置参数。使用者只需要提供少量的输入变量，就可以快速部署。

Pattern Module 基本上可以不需要额外的自定义配置，仅提供必需的参数后就可以开箱即用，并且保障了其提供的基础设施是合规的，并且是易于维护的。

优点：开箱即用，易于使用。
缺点：灵活性较差，无法满足所有的使用场景。

---

# 模式模块的例子：

[avm-ptn-aks-economy](https://registry.terraform.io/modules/Azure/avm-ptn-aks-economy/azurerm/latest) 可以部署一个经济型的 AKS 集群，适合开发和测试环境。
[avm-ptn-aks-enterprise](https://registry.terraform.io/modules/Azure/avm-ptn-aks-enterprise/azurerm/latest) 可以部署一个企业级的 AKS 集群，适合复杂的企业治理场景。

---

# 如何确保合规？

左侧的工作：[Conftest](https://www.conftest.dev/) 或是 [Checkov](https://www.checkov.io/) 可以帮助我们在 Terraform Plan 阶段就阻止不合规的配置。
右侧的工作：[Azure Policy](https://learn.microsoft.com/en-us/azure/governance/policy/overview) 或是 [AWS Config](https://aws.amazon.com/config/) 可以帮助我们在资源创建时（后），确保其合规性。

---

# 上哪去找规则库？

开源的规则库：

[PaloAlto Network Prisma (Checkov) Azure General Policies](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/azure-policies/azure-general-policies/azure-general-policies)
[PaloAlto Network Prisma (Checkov) AWS General Policies](https://docs.prismacloud.io/en/enterprise-edition/policy-reference/aws-policies/aws-general-policies/aws-general-policies)
[Trivy Checks](https://github.com/aquasecurity/trivy-checks/tree/main/checks)
[Azure/policy-library-avm](https://github.com/Azure/policy-library-avm)(可同时检查 AzureRM 与 AzAPI Provider)

---

# 如果开源规则库不够怎么办？

自己开发。个人认为，大型企业必然是要走向自研规则库的道路的。

---

# 左移 与 右移 选哪个？

小孩子才做选择，成年人都要。

左侧的优点：防范于未然，更快的反馈周期。
左侧的缺点：仍然可能被绕过，另外新增的规则需要时间来适配。

右侧的优点：你可以确信它覆盖了所有的资源，且不需要修改现有的代码，立即生效。如果开启自动 remediation 可以自动修复不合规的资源。
右侧的缺点：自动修复可能造成 Terraform Configuration Drift，排查起问题来很头疼。

建议：慎用 remediation。

---

# 合规性的保障

合规性的保障不靠模块的代码实现，也不靠预设的一组参数，而是靠左右两侧的规则工具。

应考虑设计统一的基础设施交付流水线，内建不可绕过的合规检查流程。

--- 

# 跨团队协作：模块版本管理策略与破坏性变更的控制方式

模块使用[语义化版本](https://semver.org/)。

模块分两种：

* 可复用模块(被其他模块引用的模块)
* 根模块(我们执行 `terraform apply` 的模块)

可复用模块中引用其他模块，应使用有限区间范围，至少限制 Major 版本号，例如：`~> 1.0`, `>= 1.2.3, < 2.0`。

根模块中引用其他模块，必须使用精确版本号，例如：`1.2.3`，实现[可重复构建](https://reproducible-builds.org/)。

---

# 根模块中升级引用的模块版本号流程

所有的变更都要经历变更测试。

简单的变更(不期待产生 drift)测试流程：

1. 提交代码 PR，升级引用的模块版本号
2. 代码审查
3. 批准测试，运行 `terraform plan`，检查是否有 drift
4. 如果没有 drift，批准合并 PR
5. 合并 PR，运行 `terraform apply`，完成升级

---

## 复杂的变更(期待产生 drift)测试流程

1. 提交代码 PR，升级引用的模块版本号
2. 代码审查
3. 批准测试，运行 `terraform plan`，检查是否有 drift
4. 仔细审查 drift，确认是否符合预期
5. 合并 PR，运行 `terraform apply`，完成升级

---

# 可复用模块的变更管理

可复用模块的变更管理需要遵循语义化版本控制。如果是 Minor 或是 Patch 版本的变更，要做变更测试。

1. 提交代码 PR
2. 代码审查
3. 批准测试，运行 `terraform plan`，测试新版本模块是否可以正常 apply
4. 在测试环境中签出上一个发布的 tag 版本，针对其每一个 example，运行 `terraform plan`。
5. Apply 后修改引用的 `module` 块，删除 `version`，将 `source` 指向 PR 的版本（保存于测试机器上的本地路径）。
6. 运行 `terraform init && terraform plan`，检查是否有 drift。
7. 如果没有 drift，批准合并 PR

---

## 可复用模块的变更管理

假如下一个版本是一个 Major 版本的变更，或是当前处于 `v0`，则可以跳过变更测试。

---

# 一切的变更都要经过测试、审查与批准

---

# 多环境支持：模块复用与环境隔离的常见做法

原则：一套代码，多套参数，参数分开管理。

[HashiCorp Terraform Stacks](https://www.hashicorp.com/en/blog/terraform-stacks-explained)：

```hcl
deployment "west-coast" {
  inputs = {
    aws_region     = "us-west-1"
    instance_count = 2
  }
}
 
deployment "east-coast" {
  inputs = {
    aws_region     = "us-east-1"
    instance_count = 1
  }
}
```

---

[金山世游的做法](https://mp.weixin.qq.com/s?__biz=MzI3Mzg4NTAxMw==&mid=2247486735&idx=1&sn=18cba365ba7ccfee68f54c60d3dd96f2&chksm=ea2ec81c552a17f6f559b8d7a357ea1c889f39fffd45fe4411635f68e189176316daeb14e877&mpshare=1&scene=1&srcid=0626ypvf9xqTCKO4r58G2ZXz&sharer_shareinfo=c1aafaef29f03f8f8e3ed4e3da678e3e&sharer_shareinfo_first=c1aafaef29f03f8f8e3ed4e3da678e3e&exportkey=n_ChQIAhIQvP0JI09M5PEkaCJL8q0xThKfAgIE97dBBAEAAAAAAP7lIQv%2FL6MAAAAOpnltbLcz9gKNyK89dVj0GIuJNsSB6F7nn3Vd3DeyVgVxHwe2coqWkJBSz4dI3PbNUNAdU%2Bv%2BlI8Eb3qq9z%2Fg0UQHHqUzOyDjA8R67J9ZISlpE7YQR9L7TtaSIyGaf4guITXP7Cc1QPP3ZYztUhCVqqPxixb%2FpNyVfXp7JIM1eLMXal9zGwiWJqTaSIEvNmHQFz2cPEyINrguZXoIV0wctnLtSnv9mtlb6FRrVRiuI7dcjJw20ExI9HyAiKIL6M1hjg2572LWGLeBTos%2FkONXxC8GMl1g4xj9HNAJdYnLtqvf1c0eHRX2Zi6vU0CQ%2BoRj0uVMk8XcisdlWvetlkMwjsICUhEh54KI&acctmode=0&pass_ticket=VqhgBboHJvHJZTD13VVeBaoKOdLZcDzRNdm0qDznI%2FUzzlfsOB1ec20bPhXCIiAz&wx_header=0#rd)：

```text
.
└── 产品
    ├── 测试
    │   ├── ap-northeast-1
    │   │   ├── app
    │   │   ├── db
    │   │   └── network
    │   └── us-west-1
    │       ├── app
    │       ├── db
    │       └── network
    ├── 生产
    │   ├── ap-northeast-1
    │   │   ├── app
    │   │   ├── db
    │   │   └── network
    │   └── us-west-1
    │       ├── app
    │       ├── db
    │       └── network
    └── 预演
        ├── ap-northeast-1
        │   ├── app
        │   ├── db
        │   └── network
        └── us-west-1
            ├── app
            ├── db
            └── network
```