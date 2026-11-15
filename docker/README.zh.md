# 从本地源码构建 Docker 镜像

[English](README.md) | 中文

## 概述

从当前检出目录构建 Linux 镜像，运行 Web UI 和共享的 Chromium 桌面。构建阶段会从软件源安装第三方依赖和系统包；DSH 及其 Browser Use 提供者由当前工作区编译，不安装已发布的 DSH 包。

## 目录

- [构建和启动](#build-and-start)
- [数据和端口](#data-and-ports)
- [构建与验证](#build-and-verification)
- [开发说明](#dev-note)

<a id="build-and-start"></a>

## 构建和启动

安装支持 Linux 容器的 Docker、Compose 插件、Node.js 24.9 或更新版本、Git，以及根包清单声明的 pnpm 版本。在仓库根目录运行以下命令：

```sh
pnpm docker:build
pnpm docker:up
```

打开 [Web UI](http://127.0.0.1:3080) 和 [Chromium 桌面](http://127.0.0.1:6080/vnc.html)。配置文件编辑器会在该桌面中打开。使用 Web UI 的认证流程登录，并在发送任务前配置模型提供者。

```sh
pnpm docker:logs
pnpm docker:down
```

源码变更后重新构建，再替换运行中的容器：

```sh
pnpm docker:build
node docker/compose.mjs up --detach --no-build --pull never --force-recreate
```

包装脚本会读取源码版本和 Git 提交信息供构建使用。检出目录没有 Git 元数据时，通过 `DSH_CLIENT_COMMIT_HASH` 提供已知的源码提交。Docker 仍需要联网获取基础镜像、系统包和第三方依赖。

<a id="data-and-ports"></a>

## 数据和端口

Compose 项目名为 `deepseek-harness-source`，使用与社区镜像部署分开的命名卷。`/home/node/.dsh` 保存 DSH 状态和浏览器配置；`/workspace` 保存工作文件。停止或重建容器会保留这些卷。`docker compose down --volumes` 会删除该项目的命名卷。

将 `DSH_WORKSPACE` 设置为宿主机绝对目录可绑定挂载工作区，并需确保容器 UID 1000 有写权限。端口绑定宿主机回环地址。在宿主环境或根目录 `.env` 中设置 `DSH_PORT` 和 `DSH_DESKTOP_PORT`，可修改默认的 3080 和 6080；已使用这些端口的部署需要停止或改用其他端口。

根文件系统只读，数据卷和 `/tmp` 可写。Chromium 在容器限制下使用 `--no-sandbox` 运行。noVNC 桌面没有独立密码，请保持宿主端口绑定回环地址。该容器是共享的 Agent 环境，不提供多用户隔离。`unhealthy` 状态本身不会触发容器重启。

<a id="build-and-verification"></a>

## 构建与验证

构建使用根包声明的包管理器和冻结的依赖锁文件，随后运行 `build:artifacts` 与 `build:check`。生产部署复用仓库的 pnpm 旧版部署辅助函数和已填充的依赖存储。仅构建容器中的 CLI 清单会加入本地 Browser Use 依赖；检入仓库的清单和锁文件保持不变。最终镜像包含部署后的运行产物、浏览器、桌面和容器适配脚本；宿主 `node_modules`、编译产物、Git 数据和环境文件均从构建上下文排除。

`DSH_BUILD_CONCURRENCY` 设置构建调度器的并发任务数，默认为 2。`DSH_IMAGE` 选择本地镜像标签，默认为 `deepseek-harness:local`。社区桌面插件和适配脚本连同许可证声明一起复制在此目录中；构建不依赖旁边的 Docker 仓库。

```sh
pnpm docker:check
```

路径解析和部署元数据有本地测试。Linux 中继测试覆盖 TCP 转发；Windows 无法报告相同的 POSIX 信号结果。镜像构建期间，独立检查会启动 Xvfb、调用 `explorer.exe`，并等待配置编辑器窗口出现。Compose 检查 Web 认证响应、noVNC 页面和 Chromium 调试端点。镜像构建和运行检查需要 Docker 主机，尚未在本次编写环境执行。

<a id="dev-note"></a>

## 开发说明

容器运行环境的变更由此目录以及根 Dockerfile 和 Compose 配置维护。DSH 应用行为仍由其源码包负责。
