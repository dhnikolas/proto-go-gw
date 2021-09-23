FROM golang:1.15

WORKDIR /build

ENV PROTOC_VERSION="3.13.0"
ENV PROTO_OS_VERSION="linux-x86_64"
ENV PB_REL="https://github.com/protocolbuffers/protobuf/releases"

RUN mkdir /local \
    && apt-get update \
    && apt-get install zip unzip \
    && curl -LO $PB_REL/download/v3.13.0/protoc-$PROTOC_VERSION-$PROTO_OS_VERSION.zip \
    && unzip protoc-$PROTOC_VERSION-$PROTO_OS_VERSION.zip -d /local \
    && export PATH="$PATH:/local/bin"

RUN go get -u google.golang.org/protobuf/cmd/protoc-gen-go && go install google.golang.org/protobuf/cmd/protoc-gen-go \
    && go get -u google.golang.org/grpc/cmd/protoc-gen-go-grpc && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc \
    && go get -u github.com/gogo/protobuf/protoc-gen-gogofast && go get -u github.com/envoyproxy/protoc-gen-validate

CMD /local/bin/protoc -I ${GOPATH}/src/github.com/envoyproxy/protoc-gen-validate  -I /build *.proto --go-grpc_out=. --gogofast_out=. --validate_out="lang=go:."