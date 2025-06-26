ARG GOLANG_IMAGE_TAG=1.24.4
FROM mcr.microsoft.com/oss/go/microsoft/golang:${GOLANG_IMAGE_TAG} as build
ARG CONSUL_TEMPLATE_VERSION=v0.40.0
ARG TARGETARCH
RUN export CGO_ENABLED=0 && \
    go install github.com/hashicorp/consul-template@$CONSUL_TEMPLATE_VERSION && \
    go install github.com/open-policy-agent/conftest@latest

FROM mcr.microsoft.com/devcontainers/go as runner
ARG TERRAFORM_VERSION=1.12.2
ARG VAULT_VERSION=1.19.1
ARG TARGETARCH
COPY --from=build /go/bin /bin
COPY ./setting.json /home/vscode/.vscode-remote/data/Machine/settings.json
RUN apt update && apt install -y zip unzip wget docker.io && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash && \
    curl '-#' -fL -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip && \
    unzip -q -o -d /bin/ /tmp/terraform.zip && \
    curl '-#' -fL -o /tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${TARGETARCH}.zip && \
    unzip -q -o -d /bin/ /tmp/vault.zip && \
    rm -rf /tmp
