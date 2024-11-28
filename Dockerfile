FROM ubuntu:latest

RUN apt-get update && apt-get install -y opus-tools && apt-get install -y python3 && apt-get install -y python3-pip && apt-get install -y python3-venv

WORKDIR /app

COPY . .

# Install static ffmpeg
COPY --from=mwader/static-ffmpeg:7.1 /ffmpeg /usr/bin/

# Create the virtual environment
RUN python3 -m venv /venv
ENV PATH=/venv/bin:$PATH

RUN pip3 install protobuf

# Add a script-based alias
RUN echo '#!/bin/bash\n$(which python3) /app/opus2tonie.py "$@"' > /usr/bin/audio2tonie && \
    chmod +x /usr/bin/audio2tonie