FROM golang:latest

# Install Node.js v16
RUN curl -fsSL https://deb.nodesource.com/setup_16.x | bash -
RUN apt-get install -y nodejs

# Install GlobalSign - EST Client CLI 
RUN go install github.com/lamassuiot/est/cmd/estclient@development
USER 1000