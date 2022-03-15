FROM alpine

ENV HOME=/github/home
RUN mkdir -p /github/home
RUN apk --no-cache add shadow
RUN usermod -d /github/home root

RUN echo -e "http://uk.alpinelinux.org/alpine/v3.5/main\nhttp://uk.alpinelinux.org/alpine/v3.5/community" > /etc/apk/repositories

ENV VERSION="3.5.0"
ENV BASE_URL="https://get.helm.sh"
ENV TAR_FILE="helm-v${VERSION}-linux-amd64.tar.gz"

RUN apk -v --no-cache -u add \
        bash \
        ca-certificates \
        coreutils \
        curl \
        gawk \
        git \
        jq \
        openssh \
        python && \
    apk -v --no-cache -u add --virtual .deps py-pip && \
    pip install --upgrade awscli==1.16.100 s3cmd==2.0.1 python-magic && \
    apk -v --purge del .deps

ADD https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v0.4.0/aws-iam-authenticator_0.4.0_linux_amd64 /usr/bin/aws-iam-authenticator
RUN chmod u+x /usr/bin/aws-iam-authenticator

# Install helm 3
RUN curl -L ${BASE_URL}/${TAR_FILE} |tar xvz && \
    mv linux-amd64/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-amd64

ADD https://storage.googleapis.com/kubernetes-release/release/v1.16.15/bin/linux/amd64/kubectl /usr/bin/kubectl
RUN chmod +x /usr/bin/kubectl

COPY deploy.sh /usr/local/bin/deploy

RUN chmod +x /usr/local/bin/deploy ;\
    chown 555 /usr/local/bin/deploy

RUN helm plugin install https://github.com/hypnoglow/helm-s3.git
RUN helm plugin list

ENTRYPOINT [ "/usr/local/bin/deploy" ]
