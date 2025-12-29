# README-DOCKER

This README will explain how to test `BLM::Startup::SQLiteSession`
using a Docker image.

# Building the Image

```
docker build -f Dockerfile . -t sqlite-session
```

# Running the Container

```
docker run --rm -p 80:80 sqlite-session
```

...then visit 'http://localhost:8080/bedrock/session'

# Troubleshooting

* The image is based on `bedrock-debian` so you might have some issues
  there.
* Logs should be dumped to STDOUT so you should see them in your
  terminal
* Try rebuilding `bedrock-debian`
  ```
  cd ~/git/openbedrock/docker
  make debian
  ```
