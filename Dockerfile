# Build the manager binary
FROM golang:1.18 as builder

WORKDIR /workspace
# Copy the Go Modules manifests
COPY go.mod go.mod
COPY go.sum go.sum
# cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the go source
COPY main.go main.go

# Build
RUN CGO_ENABLED=0 GOOS=linux go build -a -o gitops-repo-gc main.go


FROM registry.access.redhat.com/ubi8/ubi-minimal:8.7-1085.1679482090
RUN microdnf update --setopt=install_weak_deps=0 -y && microdnf install git

ARG ENABLE_WEBHOOKS=true
ENV ENABLE_WEBHOOKS=${ENABLE_WEBHOOKS}

# Set the Git config for the AppData bot
WORKDIR /pruner

# Install Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  && chmod +x ./kubectl \
  && mv ./kubectl /usr/local/bin/kubectl

COPY --from=builder /workspace/gitops-repo-gc .
COPY entrypoint.sh .

RUN chgrp -R 0 /pruner/ && \
    chmod -R g=u /pruner

USER 1001

ENTRYPOINT ["/entrypoint.sh"]
