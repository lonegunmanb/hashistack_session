---
marp: true

theme: gaia
paginate: true
---

# 2025/06/27 Terraform 交流

仅代表不成熟的个人观点

与 HashiCorp 以及我的雇主无关

---

# 1. Terraform Module 企业级最佳实践

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

---

# 性能优化：大型模块如何减少 `init/plan` 的耗时？

不要让模块变大。

包打天下的模块叫 [Terralith](https://mp.weixin.qq.com/s?__biz=MzI3Mzg4NTAxMw==&mid=2247484683&idx=1&sn=6442fe12e1622c0cbfe463cfa838a159&chksm=ea795c84ebadf33bd72521b89cf51d04cdadbd5577d987019a2013234af3f670584a181240a0&mpshare=1&scene=1&srcid=0626ewjnar9848TkxBrO9wMP&sharer_shareinfo=73450e8faeb495769692217f88e9ab42&sharer_shareinfo_first=73450e8faeb495769692217f88e9ab42&exportkey=n_ChQIAhIQvLtbCHtz9ORhvqt3w99kkhKfAgIE97dBBAEAAAAAANyBOuymDmsAAAAOpnltbLcz9gKNyK89dVj0X9ONXR6WayazIdNUoCwrSVbl6O1wV5Ecv0j4i0GRcaCaiHtuu6coHGVZGK9Q75loBvpGZcDCAEO5vLBkgYvqC32aVXG01pW8mEOfD6FeVHjLk1hFIXG9VemXi1NPnrdKm1bIi1cmFwko0p%2F6o3UGxyF1vvldXEsEzin5CILDvdMGrqGv6l1nm0zLHq%2FqsQrVdUYAVwN%2Fo3xqp%2F1Qr7CEpcmMS%2F6gibVsxhF6N80CBWkHgTzWrpMVCUWx4PPN8RiboxcrbGLRI8AFL8ixAEJGCidRXypeUwp0nJVS%2FpSn8vUTX6h0xo0IX0UCevzsjUw0qYGea6nGmOnY&acctmode=0&pass_ticket=fZMnEKSUayvw6aO%2BnGQC7jsoYybWbaMKSCoH3WxTsoXIIZQDh0HRdNp6pUr4C%2BBK&wx_header=0#rd) ，取意Terraform + Monolithic，即为单体 Terraform 风格

Terralith 很大，很慢，很复杂，很容易出问题([视频](https://www.youtube.com/watch?v=wgzgVm7Sqlk))

分层管理，控制爆炸半径

---

# 2. Sentinel Policy 在非 TFE 场景的实践

---

# 非 TFE 环境中，是否有推荐的策略实施方式

`conftest` 我觉得不错，Opa 需要学习掌握一下写法

`checkov` 因为是 Python 项目，更新规则会比较麻烦，但现在也支持 Opa 了

重要的是好的规则库，而且自己能够定制化。

要考虑多 Provider，例如 `aws` 和 `awscc`，`azurerm` 和 `azapi` 可能同时存在。

---

## 常见策略如资源加密、实例规格限制等，如何以较低成本落地

首先构建中央管控的，标准的基础设施交付流水线，各产品组可以在在各自的代码库中集成（类似 AVM 的模板仓库创建的大量模块仓库），控制住流水线，就可以往流水线中安插各种规则限制

---

# 3. 多云与协作实践挑战

---

# 状态管理：Workspace 与目录结构在大规模场景下的优劣与风险

`workspace` 在 Terraform 语境中有两个不同的含义，如果是 Terraform 命令行工具带有的 `workspace` 命令，我的建议是：不要用。[官方文档](https://developer.hashicorp.com/terraform/cli/workspaces#use-cases)也说的很清楚：

>A common use for multiple workspaces is to create a parallel, distinct copy of a set of infrastructure to test a set of changes before modifying production infrastructure.

仅为测试

---

# Terraform Cloud 或是 HCP Terraform 或是 TFE 的 workspace

没用过。。。应该是必用的功能吧。

---

# 模块抽象：如何设计跨多云的统一接口模块

我认为：[极不可能](https://mp.weixin.qq.com/s?__biz=MzI3Mzg4NTAxMw==&mid=2247484484&idx=1&sn=3034327f714cc3f71da6c67b53beb039&chksm=eaee8f94c05a0c59e19132ba3944c5bed28358eed97f541fa720dc36cfb9f70bbba9d11403f3&mpshare=1&scene=1&srcid=0626x0ODP24DpJ1UbeCLZz6w&sharer_shareinfo=5c592b6e2682b13261d21fdd0e6a1c4e&sharer_shareinfo_first=5c592b6e2682b13261d21fdd0e6a1c4e&exportkey=n_ChQIAhIQQg8odppoLrQyy8AY6GdkiBKfAgIE97dBBAEAAAAAAJxvKjYan%2FYAAAAOpnltbLcz9gKNyK89dVj0OxPK9ozebq1z4WGks7Oog0aSOOW8MYBz7UKXKydKNHzsktI8WDMKnG7IHndcrrEjtGjq6ju9peg%2FoDzWeVynDAMipO7suCKDQW%2FfxR7kyux%2BCzlZeJPUOmgDx%2Bs8lrt0bNZA0IcTN21%2BcGikeO0qDk7pHZ87sy7NlxCQsBqQzPSNxr34Qbid1UrMXmFYKtANqlN7BlSjOktFRWVXSQTd3zwSShToInH5tReaTbmOd%2BYQ9rjaQEnjq7i98gncG%2FqcQVfgag0Tp6PtnrnS8d1NaRMQsfdZ4ICCF%2B3kPnUgr9%2BdzAcohJ3KRYMsyxPRwpJxwaS34OAKM20L&acctmode=0&pass_ticket=o2UpJTZj0r3%2BLHaeB%2FVVmttiG38j1dBWyFjpxcJV0D9tbjivIXGSmBa1t2lZHlPW&wx_header=0#rd)

不同云厂商的产品大相径庭，细节上差别很大

细颗粒度的抽象（抽象虚拟机，抽象 VPC）基本不可能

重新思考，以应用为基础抽象单元似乎可行（这是我们的鉴权微服务，它有两个实现，模块 A 可以部署在 A 云上，模块 B 可以部署在 B 云上），应用可以有一些共享的抽象接口，例如部署尺寸（大，超大，互联网一线大厂那么大，对应到不同云的 sku）

---

## 模块抽象：如何设计跨多云的统一接口模块

我们仍然可以提供一些不同云上的基础模块，例如数据库、安全组，但这些模块仍然会带有浓重的各自云的痕迹

想要完全依赖抽象，屏蔽掉云的各种细节去使用抽象模块接口部署个人认为不现实，也没有必要

但可以部分实现，例如，基于 K8s、HashiCorp Nomad 提供统一的应用调度层，基于这种类似“云 OS”再去统一上层的部署是完全可行的

---

## 模块抽象：如何设计跨多云的统一接口模块

我们目前的一个尝试方向：积累大量的模块，以及样例代码，构建一个 [RAG](https://aws.amazon.com/what-is/retrieval-augmented-generation/) 知识库

尝试利用 AI 针对具体问题进行拆解、分层，选择合适的模块，人类用户选择预设的套餐型参数，AI 尝试将模块胶合在一起

个人认为，灵活性上必然要做一些妥协和牺牲，换取便利性和效率

---

# 4. 如何看待国内在 Terraform 落地方面相比海外的接受度差异

---

# 碎片化问题

根据最新可靠来源（ChatGPT 与 Gemini），2024 年 AWS、Azure 和 Google Cloud 在全球公有云（IaaS + PaaS）市场中的市占率大致如下：

* Amazon Web Services (AWS)：约 31–32% 
* Microsoft Azure：约 23–25% 
* Google Cloud：约 11–12% 

三个厂商合计占据全球公有云市场约 65–69% 的份额，普遍估算在**约 66–68%**之间

---

## 冷启动

https://github.com/hashicorp/terraform-provider-aws
https://github.com/hashicorp/terraform-provider-awscc
https://github.com/hashicorp/terraform-provider-azurerm
https://github.com/hashicorp/terraform-provider-google

它们都是 HashiCorp 开发维护的

覆盖这三个云（甚至只需要覆盖 AWS）就足以覆盖足够大的市场

---

# 国内云平台高度碎片化

阿里云	~34%
华为云	~16%
中国电信	~15%
腾讯云	~13%
中国移动	~11%
其他（百度云、联通云等）	~11%

公有云本身在中国尚未成为主流，私有云、传统数据中心更常见

鸡和蛋的冷启动问题

---

# 观念问题

私有云更安全？
老方法更可靠？

当前的中国用 40 年走完别人上百年的路，结果就是上百年前的人和今天的 00 后 10 后同场竞技，而他们仍然掌握着关键决策权

---

# [科技三定律](https://www.forbes.com/sites/sap/2014/07/07/douglas-adams-technology-rules/)

1. 任何在我出生时已经有的科技都是稀松平常的世界本来秩序的一部分。
2. 任何在我15-35岁之间诞生的科技都是将会改变世界的革命性产物。
3. 任何在我35岁之后诞生的科技都是违反自然规律要遭天谴的。

---

![alt text](image-1.png)

---

# 谨慎乐观

[中国经济增速开始放缓对云和软件可能并非全是坏事](https://mp.weixin.qq.com/s?__biz=MzI3Mzg4NTAxMw==&mid=2247487747&idx=1&sn=c4ec87e47f56203987269b7e75fa960d&chksm=eae125b0d79a9ea00b8d515e85f33c8df1d208fdf1b870a5ba9a1338b0f75b6727c578dde216&mpshare=1&scene=1&srcid=0626AhSPfdJYGLwlkWVojq3R&sharer_shareinfo=9ebe260de228dcc95d0b0510fd0c2fb6&sharer_shareinfo_first=9ebe260de228dcc95d0b0510fd0c2fb6&exportkey=n_ChQIAhIQQaSAo8uN4KyjMy7UTCiGcRKfAgIE97dBBAEAAAAAABspBNDYfCYAAAAOpnltbLcz9gKNyK89dVj07pP%2BU1LOh0%2BDUo0Kikf1Xqdtv9kj98P%2FH%2BoQlCs9Y1ZpVQjpv2f6KdBQaovrCRegmIKgZ2YecI1%2B2fEDq%2BVRWomGzbmmrdYzyd30c%2B15vj76RNhAc3q%2BMvV80uHBv1GI%2FtdXY%2Fvm%2B9TAmUjTi7zgb6MCtIMKrZsgale4uj0BMCIq5LoXdlyZSynVMAl%2Fckva8SnCz3RKsSQgTrMycWmhnZ99SixWHWTNsSAlrn5pKaw0nNkl%2F2cjPGZLENre8R9h9WzdUcw7AhcPlZIpzw9WtKlr9oME6OA%2FmMRQgvY6lcvWIixezMzpi344FNkLKuS3qRWFQLS69YHx&acctmode=0&pass_ticket=SuhyFt0kExWP%2BxPgudjPDDZnIpTsLMRC2awSJebSjeaZbxX64%2FhqhT4MnV%2BZa4vM&wx_header=0#rd)

[中国的云计算革命尚未开始](https://mp.weixin.qq.com/s?__biz=MzI3Mzg4NTAxMw==&mid=2247485306&idx=1&sn=69bc1d02f57f8c2caef57f77c8617fe3&chksm=ea4a93aea7f7c9407641c0630c47a3fc07cfb3704884b50f6d32baea637d97c2f45ef3a32dc7&mpshare=1&scene=1&srcid=0626fLOlLgq60cnVfOGR38yp&sharer_shareinfo=393afea9c20b3608ff261b8f3d2db87a&sharer_shareinfo_first=393afea9c20b3608ff261b8f3d2db87a&exportkey=n_ChQIAhIQ0GM8BIAdLZPb9FajrKnhSRKfAgIE97dBBAEAAAAAAPpyLU%2BVcBAAAAAOpnltbLcz9gKNyK89dVj0T8wpMWVtLAdr%2BSIB%2FW1RY7IkmykS6sAbPKTPUtp6icNgCvrUofAy1R2weEGcJo7mfo0o1Y93vOjFrjaH3oBlT6aRfvfa%2FzHmZMHHc1EaIyenqLxi8SeXghToSZdhA%2BdqqQz7EiOSHwFNGcxIOl6r9S2SJSCRmNCk9a3pk%2FE%2FJYQtXgxc6rWe6E41EiSu0gvk1Ct3iJYv3I2eazDD%2BwjeBq0tDDetHu2iBH%2F8azEHMKY7YNo8QL3mdPRZWinG9RBrxR9fJTB2BQE3WHZuQz%2BpBGhXOCuHDfyZGa%2F0eYXEHRPTnB4np96ysAj8OLRAa58xhQt5bG%2FpfHCe&acctmode=0&pass_ticket=j6bpJdOYChbVupLEFzBqEY0XIUskKtQlKw4zOdi6TsCcITb5PxDYOMEHIj4iMIP0&wx_header=0#rd)

我们的问题在于，中国发展的太快了，我们还来不及消化掉旧观念、旧资产、旧人，就迎来了新观念、新资产、新人

红利一代掌握的话语权，但他们是被上一代的工具（ITIL）塑造的

工具塑造人（汽车决定现代城市的结构，计算机与网络决定现代人的工作、娱乐、交友方式）

---

# 谨慎乐观

>批判的武器当然不能代替武器的批判，物质力量只能用物质力量来摧毁，但是理论一经掌握群众，也会变成物质力量。 理论只要说服人，就能掌握群众；而理论只要彻底，就能说服人。 —— 至圣先师

![height:400px](image.png)

---

# 谨慎乐观

在跑马圈地大跃进的时代，精细化管理只会让你圈地速度变慢

试图说服成吉思汗采用现代化军事理论是没有意义的，你一年抢的地还没他一个星期跑的多，另外你也不可能把坦克飞机大炮卫星带回南宋

假如飞机大炮的技术是有用的，那么关键不是让成吉思汗接受你的理论去用飞机大炮，而是组建一直使用飞机大炮的军队，让成吉思汗从能征善战变成能歌善舞

大众宝马丰田并不是想穿了接受了电动车的技术路线，而是被特斯拉比亚迪们打的没有办法了

---

# 谨慎乐观

[《创新者的窘境》](https://www.amazon.com/%E5%88%9B%E6%96%B0%E8%80%85%E7%9A%84%E7%AA%98%E5%A2%83-%E5%85%A8%E6%96%B0%E4%BF%AE%E8%AE%A2%E7%89%88-%E5%85%8B%E8%8E%B1%E9%A1%BF-%C2%A1%C3%A8%E5%85%8B%E9%87%8C%E6%96%AF%E5%9D%A6%E6%A3%AE/dp/B076TVM6H6)：

>成熟企业致力于在成熟市场引入破坏性技术，而成功的新兴企业则发现了一个看重这种技术的新市场

HashiCorp Terraform 一开始的用户并非世界 500 强，AWS 亦然

新技术、新思想的落地，往往始于帝国的边疆，那些巨头看不上的角落种萌发出的，满脑子“弯道超车”的野蛮人

与其等着老钱被说服，不如寻找有野心的新钱，武装起来，去抢老钱

---

# 谨慎乐观

人总是要死的，老人死的早一点