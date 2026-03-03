# How to Install

```
curl -sL https://github.com/rhythwitty/bashrepo/raw/main/scripts/downloadyoutube.sh -o downloadyoutube && chmod +x downloadyoutube && sudo mv downloadyoutube /usr/local/bin/downloadyoutube
```

Then to use:

```
downloadyoutube --update <self|ytdlp>
downloadyoutube https://youtube.com/watch?v=...           # chrome, 1080p
downloadyoutube -b firefox -r 720 https://...            # firefox, 720p
downloadyoutube --browser safari --resolution 480 https://...
```