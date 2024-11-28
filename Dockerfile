FROM python:3.13.0-slim-bookworm

RUN apt-get update && apt-get install -y opus-tools

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