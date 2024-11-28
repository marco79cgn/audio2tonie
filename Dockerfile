FROM python:3.13.0-slim-bookworm

RUN apt-get update && apt-get install -y opus-tools

WORKDIR /app

# Copy opus2tonie files
COPY opus2tonie.py .
COPY tonie_header.proto .
COPY tonie_header_pb2.py .

# Install static ffmpeg
COPY --from=mwader/static-ffmpeg:7.1 /ffmpeg /usr/bin/

# Create the virtual environment
RUN python3 -m venv /venv
ENV PATH=/venv/bin:$PATH

# Install protobuf
RUN pip3 install protobuf

# Add a script-based alias
RUN echo '#!/bin/bash\n$(which python3) /app/opus2tonie.py "$@"' > /usr/bin/audio2tonie && \
    chmod +x /usr/bin/audio2tonie