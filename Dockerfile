FROM golang:1.15

WORKDIR /build
COPY --from=swaggerapi/swagger-ui /usr/share/nginx/html/ /swagger-ui/

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

RUN go mod init build && go mod edit -require github.com/grpc-ecosystem/grpc-gateway@v1.16.0 -require github.com/grpc-ecosystem/grpc-gateway/v2@v2.6.0 \
    && go mod tidy && mkdir http \
    && go get github.com/go-bindata/go-bindata/... \
    && go install \
        github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway \
        github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2

CMD /local/bin/protoc -I ${GOPATH}/src/github.com/envoyproxy/protoc-gen-validate \
       -I ${GOPATH}/pkg/mod/github.com/grpc-ecosystem/grpc-gateway@v1.16.0/third_party/googleapis \
       -I ${GOPATH}/pkg/mod/github.com/grpc-ecosystem/grpc-gateway/v2@v2.6.0 \
       --grpc-gateway_out . \
       --grpc-gateway_opt logtostderr=true \
       --grpc-gateway_opt paths=source_relative \
       --openapiv2_out . \
       --openapiv2_opt logtostderr=true \
       -I /build *.proto --go-grpc_out=. --go_out=. --validate_out="lang=go:." \
    && cp $(find . -name "*.swagger.json") /swagger-ui/swagger.json \
    && sed -i "s|https://petstore.swagger.io/v2/swagger.json|./swagger.json|g" /swagger-ui/index.html \
    && go-bindata -o /build/swagger/swagger.go -nomemcopy -pkg=swagger -prefix "/swagger-ui/" /swagger-ui
