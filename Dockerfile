FROM ubuntu

# Install helm and dependencies
RUN apt -y update && apt install -y curl git tar openssl unzip \
    # Get the latest aws cli tools
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm awscliv2.zip \
    # Install helm
    && curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash \
    # Install kubectl
    && curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl && mv ./kubectl /usr/local/bin/kubectl
    
COPY deploy.sh /usr/local/bin/deploy

RUN chmod +x /usr/local/bin/deploy ;\
    chown 555 /usr/local/bin/deploy

RUN helm plugin install https://github.com/hypnoglow/helm-s3.git

ENTRYPOINT [ "/usr/local/bin/deploy" ]
