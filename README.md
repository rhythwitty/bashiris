# iris

A unified CLI for utility scripts. Works on macOS and Linux.

## Install

```bash
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/install.sh | bash
```

## Usage

```bash
iris                    # list available commands
iris <command> [args]   # run a command
iris --update           # update iris and all scripts
iris --version          # show version
```

## Commands

### check-power
```bash
iris check-power
```

### download-yt
```bash
iris download-yt https://youtube.com/watch?v=...
iris download-yt -b firefox -r 720 https://...
iris download-yt --browser safari --resolution 480 https://...
iris download-yt --update ytdlp
iris download-yt --help
```

### kill-port
```bash
iris kill-port <port_number>
```

### setup-ssh
```bash
iris setup-ssh
```

## Adding a new command

1. Add a script to `scripts/<command-name>.sh`
2. Include `# IRIS_DESC: <short description>` near the top
3. Add the command name to the `SCRIPTS` array in `install.sh`