# bark-runner

![bash](https://img.shields.io/badge/shell-bash-blue)
![license](https://img.shields.io/badge/license-MIT-green)

> A lightweight shell job runner with Bark notifications, SSH-safe background execution, log tracking, and simple job management.

🌐 **Language:** English | [中文](README.zh.md)

---

## Features

- Run long shell commands in the background
- Survive SSH disconnects
- Send Bark notifications when jobs finish
- Include log tail in notifications
- Track jobs with unique `job_id`
- List running jobs and history
- Tail logs by job name or `job_id`
- Kill jobs easily
- Remove job records
- Built-in bilingual support (`R_LANG=en|zh`)

---

## Installation

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

## Configuration

```bash
export BARK_KEY="your_device_key"
export R_LANG="en"   # or zh
```

---

## Quick Start

### Run a job

```bash
r "python train.py"
```

```bash
r -n experiment "python train.py"
```

```bash
r -n matlab_us -l output.log "matlab -nodisplay -r 'run_all; exit'"
```

---

### List jobs

```bash
r ls
r ls -a
```

---

### Tail logs

```bash
r tail matlab_us
r tail matlab_us -n 200
r tail job_20260403_153000_12345
```

---

### Kill jobs

```bash
r kill matlab_us
r kill job_20260403_153000_12345
```

---

### Remove records

```bash
r rm matlab_us
r rm job_20260403_153000_12345
r rm -a
r rm -aa
```

---

## Why bark-runner?

Running long jobs over SSH is painful:

* SSH disconnect kills workflow
* No notification when finished
* Logs are messy
* Hard to track multiple jobs

`bark-runner` solves all of this with a single command.

---

## Notes

* `r ls` shows unfinished jobs only
* `r ls -a` shows full history
* Logs are **not deleted** by `r rm`
* Uses local TSV database

---

## License

MIT