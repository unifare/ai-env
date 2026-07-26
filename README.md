# ai-env

**AI API Key Manager** — 一键管理你的 AI API Keys，告别手动编辑 `.bashrc`。

## 特性

- 🚀 安装一次，永久使用
- 🔒 安全存储，自动权限管理（600）
- ⚡ 当前终端立即生效，新终端自动加载
- 🐚 支持 Bash / Zsh
- 📦 零依赖，纯 Bash 实现
- 🖥️ 全平台：Ubuntu / Debian / CentOS / Rocky / AlmaLinux / WSL / macOS

## 快速安装

```bash
curl -fsSL https://example.com/install.sh | bash
```

或者克隆后本地安装：

```bash
git clone https://github.com/yourname/ai-env.git
cd ai-env
./install.sh
```

## 使用方法

### 设置 API Key

```bash
ai-env set OPENAI_API_KEY sk-xxxxxxxxxxxxxxxx
# ✓ OPENAI_API_KEY set
```

> 当前终端立即生效，无需手动 `export`。

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
# GEMINI_API_KEY                        AIz****zzzz
```

> 值自动脱敏，不会暴露完整 Key。

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
# ✓ Config directory: ~/.config/ai-env
# ✓ ai-env in PATH: ~/.local/bin/ai-env
# ✓ Shell integration in .bashrc
# ✓ Shell function loaded
# ✓ Keys file exists (3 keys)
# ✓ Keys file permissions: 600 (secure)
```

### 查看版本

```bash
ai-env version
# ai-env v1.0.0
```

## 命令一览

| 命令 | 说明 |
|------|------|
| `ai-env set <KEY> <VALUE>` | 设置环境变量 |
| `ai-env get <KEY>` | 获取变量值 |
| `ai-env list` | 列出所有变量（值脱敏） |
| `ai-env remove <KEY>` | 删除变量 |
| `ai-env reload` | 重新加载所有变量 |
| `ai-env export` | 导出所有变量 |
| `ai-env doctor` | 运行诊断检查 |
| `ai-env version` | 显示版本 |
| `ai-env help` | 显示帮助 |

别名：`list` = `ls`，`remove` = `rm` / `delete` / `unset`

## 工作原理

### 安装时

1. 创建 `~/.config/ai-env/` 目录
2. 安装 `ai-env` 脚本到 `~/.local/bin/` 或 `/usr/local/bin/`
3. 在 `~/.bashrc` / `~/.zshrc` 中添加 `source ~/.config/ai-env/init.sh`
4. 当前终端立即加载

### 每次打开终端

1. Shell 读取 `.bashrc` / `.zshrc`
2. `source init.sh` → 加载所有 Keys
3. 注册 `ai-env` 包装函数（使 `set` / `remove` 立即生效）

### set 命令时

1. 写入 `~/.config/ai-env/keys` 文件
2. 通过 `__EVAL__` 协议在当前 Shell 执行 `export`
3. 当前终端立即生效 ✅
4. 下次打开终端自动加载 ✅

## 目录结构

### 项目源码

```
ai-env/
├── README.md          # 文档
├── install.sh         # 安装脚本
├── uninstall.sh       # 卸载脚本
├── ai-env             # 主程序
├── init.sh            # Shell 初始化
├── config             # 默认配置
└── tests/
    └── test.sh        # 测试脚本
```

### 安装后（用户系统）

```
~/.config/ai-env/
    keys               # API Keys 存储（chmod 600）
    config             # 配置文件
    init.sh            # Shell 初始化脚本

~/.local/bin/ai-env    # CLI 主程序
```

## 安全性

- ✅ 变量名校验：只允许 `[A-Za-z_][A-Za-z0-9_]*`
- ✅ 值正确转义：单引号安全处理
- ✅ 禁止重复变量
- ✅ 禁止破坏其它环境变量
- ✅ Keys 文件权限 600（仅所有者可读写）
- ✅ 安装脚本支持重复执行（幂等）
- ✅ List 命令自动脱敏

## 卸载

```bash
./uninstall.sh
```

可选择保留 keys 备份文件 `~/.ai-env-keys.backup`。

## 测试

```bash
./tests/test.sh
```

## 许可证

MIT License
