FROM --platform=linux/amd64 golang:1.17

WORKDIR /build
COPY --from=swaggerapi/swagger-ui /usr/share/nginx/html/ /swagger-ui/

ENV PROTOC_VERSION="3.13.0"
ENV PROTO_OS_VERSION="linux-x86_64"
ENV PB_REL="https://github.com/protocolbuffers/protobuf/releases"

RUN mkdir /local \
    && apt-get update \
    && apt-get install zip unzip \
    && curl -LO $PB_REL/download/v$PROTOC_VERSION/protoc-$PROTOC_VERSION-$PROTO_OS_VERSION.zip \
    && unzip protoc-$PROTOC_VERSION-$PROTO_OS_VERSION.zip -d /local \
    && export PATH="$PATH:/local/bin"

RUN go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.28.0  \
    && go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.2.0  \
    && go install github.com/envoyproxy/protoc-gen-validate@v0.6.7

RUN mkdir http \
    && go install github.com/go-bindata/go-bindata/...@latest \
    && go install \
        github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway@v2.10.3 \
        github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2@v2.10.3 \
    && git clone https://github.com/googleapis/googleapis.git ${GOPATH}/google/googleapis

RUN echo ' \n\
package swagger \n\
import "os" \n\
func GetAsset() func (name string) ([]byte, error)  {return Asset} \n\
func GetAssetInfo() func(name string) (os.FileInfo, error) {return AssetInfo} \n\
func GetAssetDir() func(name string) ([]string, error) {return AssetDir}' >> /var/wrapper.go

CMD /local/bin/protoc \
       -I ${GOPATH}/pkg/mod/github.com/envoyproxy/protoc-gen-validate@v0.6.7 \
       -I ${GOPATH}/pkg/mod/github.com/grpc-ecosystem/grpc-gateway/v2@v2.10.3 \
       -I /${GOPATH}/google/googleapis \
       --grpc-gateway_out . \
       --grpc-gateway_opt logtostderr=true \
       --openapiv2_out . \
       --openapiv2_opt logtostderr=true \ 
       --openapiv2_opt allow_merge=true \
       --openapiv2_opt merge_file_name=api \
       -I /build *.proto --go-grpc_out=. --go_out=. --validate_out="lang=go:." \
    && if [ -f **/*.pb.gw.go ]; then \
    cp $(find . -name "*.swagger.json") /swagger-ui/swagger.json \
    && sed -i "s|https://petstore.swagger.io/v2/swagger.json|./swagger.json|g" /swagger-ui/index.html \
    && go-bindata -o /build/swagger/swagger.go -nomemcopy -pkg=swagger -prefix "/swagger-ui/" /swagger-ui \ 
    && cp /var/wrapper.go /build/swagger/; \
    else rm -rf "api.swagger.json"; fi