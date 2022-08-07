FROM ubuntu:14.04

COPY sources.list /etc/apt/sources.list

RUN apt update && apt install -y gcc-4.8 && \
    apt install -y libncurses5-dev build-essential && \
    apt install -y lib32readline-gplv2-dev

CMD ["bash"]
