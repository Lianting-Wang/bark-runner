# bark-runner

![bash](https://img.shields.io/badge/shell-bash-blue)
![license](https://img.shields.io/badge/license-MIT-green)

> 一个轻量级的 Shell 任务运行工具，支持 Bark 通知、断开 SSH 后持续运行、日志记录和简单任务管理。

🌐 **语言:** [English](README.md) | 中文

---

## 功能特性

- 后台运行长时间任务
- 默认按顺序排队执行任务
- 使用 `-p` 可立即并行运行
- SSH 断开后任务仍继续执行
- 任务结束自动发送 Bark 通知
- 通知中包含日志尾部
- 使用唯一 `job_id` 跟踪任务
- 查看当前任务和历史记录
- 支持按任务名或 `job_id` 查看日志
- 支持终止任务
- 支持删除任务记录
- 内置中英文支持（`R_LANG=en|zh`）

---

## 安装

```bash
git clone https://github.com/<your-username>/bark-runner.git
cd bark-runner

mkdir -p ~/.bin
cp r ~/.bin/r
chmod +x ~/.bin/r

echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
````

---

## 配置

```bash
export BARK_KEY="your_device_key"
export R_LANG="zh"   # 或 en
```

---

## 快速开始

### 提交任务

```bash
r "python train.py"
```

```bash
r -n experiment "python train.py"
```

```bash
r -p "python train.py"
```

```bash
r -n matlab_us -l output.log "matlab -nodisplay -r 'run_all; exit'"
```

---

### 查看任务

```bash
r ls
r ls -a
```

---

### 查看日志

```bash
r tail matlab_us
r tail matlab_us -n 200
r tail job_20260403_153000_12345
```

---

### 终止任务

```bash
r kill matlab_us
r kill job_20260403_153000_12345
```

---

### 删除记录

```bash
r rm matlab_us
r rm job_20260403_153000_12345
r rm -a
r rm -aa
```

---

## 为什么使用 bark-runner？

在远程服务器上跑长任务时通常会遇到：

* SSH 断开影响任务管理
* 任务结束没有通知
* 日志混乱
* 多任务难以管理

`bark-runner` 用一个简单命令解决这些问题。

---

## 注意事项

* `r` 默认排队执行任务；使用 `r -p ...` 可跳过队列
* `r ls` 默认只显示未完成任务
* `r ls -a` 显示全部历史
* `r rm` 不会删除日志文件
* 使用本地 TSV 文件存储任务信息

---

## 许可证

MIT
