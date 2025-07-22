FROM python:3.13.5-slim-bookworm@sha256:6a052e11d3de2d0d55b94707ba4dd6786c10fb66610061e0a5396039a6ca2411

RUN apt-get update && apt-get install -y opus-tools && apt-get install -y curl && apt-get install -y jq

WORKDIR /app

# Copy opus2tonie files
COPY opus2tonie.py .
COPY tonie_header.proto .
COPY tonie_header_pb2.py .
COPY audio2tonie.sh .

# Install static ffmpeg
COPY --from=mwader/static-ffmpeg:7.1 /ffmpeg /usr/bin/

# Create the virtual environment
RUN python3 -m venv /venv
ENV PATH=/venv/bin:$PATH

# Install protobuf
RUN pip3 install protobuf

# Add a script-based aliases
RUN echo '#!/bin/bash\n/app/audio2tonie.sh "$@"' > /usr/bin/transcode && \
    chmod +x /usr/bin/transcode
RUN echo '#!/bin/bash\n$(which python3) /app/opus2tonie.py "$@"' > /usr/bin/opus2tonie && \
    chmod +x /usr/bin/opus2tonie