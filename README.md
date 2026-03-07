# How to Install

```bash
# Install download-yt
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/scripts/download-yt.sh -o download-yt && chmod +x download-yt && sudo mv download-yt /usr/local/bin/download-yt

# Install kill-port
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/scripts/kill-port.sh -o kill-port && chmod +x kill-port && sudo mv kill-port /usr/local/bin/kill-port
```

Then to use:

### download-yt
```bash
download-yt --update <self|ytdlp>
download-yt https://youtube.com/watch?v=...           # chrome, 1080p
download-yt -b firefox -r 720 https://...            # firefox, 720p
download-yt --browser safari --resolution 480 https://...
```

### kill-port
```bash
kill-port <port_number>
```