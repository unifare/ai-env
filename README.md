# ai-env

**AI API Key Manager** — 一键跨平台管理你的 AI API Keys，告别手动编辑配置文件。

[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-blue.svg)](https://github.com/unifare/ai-env)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 特性

- 🚀 **一键安装，跨平台支持**：支持 Windows (PowerShell, CMD, Git Bash, WSL)、Linux、macOS。
- 🔒 **安全存储**：脱敏展示，自动生成与管理存储文件，防止 Key 泄漏。
- ⚡ **即时生效**：当前终端立即生效，新开终端自动加载。
- 🛠️ **多 Shell 兼容**：支持 Bash / Zsh / PowerShell / CMD。
- 📋 **双模管理脚本**：内置 `manage.ps1` 和 `manage.sh`，支持交互式数字菜单与命令行参数。
- 📦 **零额外依赖**：纯 PowerShell / Bash 实现。

## 快速安装

### Windows (PowerShell)

在 PowerShell 中运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

或者使用管理脚本：

```powershell
.\manage.ps1 install
```

### Linux / macOS / Git Bash / WSL

在 Bash 中运行：

```bash
curl -fsSL https://raw.githubusercontent.com/unifare/ai-env/main/install.sh | bash
```

或者本地安装：

```bash
./install.sh
# 或使用管理脚本
./manage.sh install
```

---

## 🛠️ 管理脚本 (manage.ps1 / manage.sh)

`ai-env` 提供了方便的管理脚本，支持**数字选择菜单**和**命令行参数**两种方式：

### 1. 交互式数字菜单

无参数直接运行脚本即可进入图形化菜单：

```powershell
# Windows
.\manage.ps1

# Linux / macOS / Git Bash
./manage.sh
```

菜单界面如下：
```text
========================================
     ai-env Management Tool
========================================
 1. Install ai-env
 2. Set API Key (set)
 3. Get API Key (get)
 4. List API Keys (list)
 5. Remove API Key (remove)
 6. Reload Keys (reload)
 7. Export Keys (export)
 8. Run Diagnostics (doctor)
 9. Show Version (version)
10. Uninstall ai-env
 0. Exit
========================================
Please enter your choice [0-10]:
```

### 2. 命令行参数

管理脚本支持带参数直接调用：

```bash
# 安装 / 卸载
./manage.sh install
./manage.sh uninstall

# Key 管理操作
./manage.sh set OPENAI_API_KEY sk-xxxxxxxx
./manage.sh get OPENAI_API_KEY
./manage.sh list
./manage.sh doctor
```

---

## CLI 命令使用方法

### 设置 API Key

```bash
# Bash / Zsh / Git Bash
ai-env set OPENAI_API_KEY sk-xxxxxxxxxxxxxxxx

# PowerShell
ai-env set OPENAI_API_KEY sk-xxxxxxxxxxxxxxxx
```

> 当前终端立即生效，无需手动 `export` 或重启 PowerShell。

### 获取 Key 值

```bash
ai-env get OPENAI_API_KEY
# sk-xxxxxxxxxxxxxxxx
```

### 列出所有 Keys

```bash
ai-env list
# KEY                                  VALUE
# -----------------------------------  -------------------
# OPENAI_API_KEY                       sk-x****xxxx
# ANTHROPIC_API_KEY                    sk-a****yyyy
# GEMINI_API_KEY                       AIz****zzzz
```

> 值自动脱敏，防止屏幕泄漏。

### 删除 Key

```bash
ai-env remove OPENAI_API_KEY
# ✓ OPENAI_API_KEY removed
```

### 重新加载

```bash
ai-env reload
# ✓ Reloaded 3 key(s)
```

### 导出所有 Keys

```bash
ai-env export > ~/.env.backup
```

### 健康检查

```bash
ai-env doctor
# ✓ Config directory: C:\Users\Username\.config\ai-env
# ✓ ai-env in PATH: ...
# ✓ Shell integration in profile
# ✓ Keys file exists (3 keys)
# ✓ All checks passed
```

### 查看版本

```bash
ai-env version
# ai-env v1.0.0
```

---

## 命令一览

| 命令 | 说明 | 别名 |
|------|------|------|
| `ai-env set <KEY> <VALUE>` | 设置环境变量 | - |
| `ai-env get <KEY>` | 获取变量值 | - |
| `ai-env list` | 列出所有变量（脱敏） | `ls` |
| `ai-env remove <KEY>` | 删除变量 | `rm`, `delete`, `unset` |
| `ai-env reload` | 重新加载所有变量 | - |
| `ai-env export` | 导出所有变量 | - |
| `ai-env doctor` | 运行诊断检查 | - |
| `ai-env version` | 显示版本 | `-v`, `--version` |
| `ai-env help` | 显示帮助 | `-h`, `--help` |

---

## 目录结构

```
ai-env/
├── README.md          # 文档
├── install.sh         # Linux/Unix 安装脚本
├── uninstall.sh       # Linux/Unix 卸载脚本
├── install.ps1        # Windows PowerShell 安装脚本
├── uninstall.ps1      # Windows PowerShell 卸载脚本
├── manage.sh          # Linux/Unix 管理脚本 (菜单 + 参数)
├── manage.ps1         # Windows 管理脚本 (菜单 + 参数)
├── ai-env             # Bash 主程序
├── ai-env.ps1         # PowerShell 主程序
├── ai-env.cmd         # Windows CMD 包装脚本
├── init.sh            # Bash Shell 初始化
├── init.ps1           # PowerShell 初始化
├── config             # 默认配置
└── tests/
    ├── test.sh        # Bash 测试套件
    └── test.ps1       # PowerShell 测试套件
```

---

## 卸载

```bash
# Windows
.\manage.ps1 uninstall
# 或: powershell -ExecutionPolicy Bypass -File .\uninstall.ps1

# Linux / macOS / Git Bash
./manage.sh uninstall
# 或: ./uninstall.sh
```

卸载时自动生成 Key 备份文件 `~/.ai-env-keys.backup`。

---

## 测试

运行测试套件：

```bash
# Bash (Linux/macOS/Git Bash)
./tests/test.sh

# PowerShell (Windows)
powershell -ExecutionPolicy Bypass -File .\tests\test.ps1
```

## 许可证

MIT License
