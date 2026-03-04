# How to Install

```bash
# Install downloadyoutube
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/scripts/downloadyoutube.sh -o downloadyoutube && chmod +x downloadyoutube && sudo mv downloadyoutube /usr/local/bin/downloadyoutube

# Install killport
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/scripts/killport.sh -o killport && chmod +x killport && sudo mv killport /usr/local/bin/killport
```

Then to use:

### downloadyoutube
```bash
downloadyoutube --update <self|ytdlp>
downloadyoutube https://youtube.com/watch?v=...           # chrome, 1080p
downloadyoutube -b firefox -r 720 https://...            # firefox, 720p
downloadyoutube --browser safari --resolution 480 https://...
```

### killport
```bash
killport <port_number>
```