# grpc_web_proto_library
grpc_web_proto_library runs the proto compiler using the grpc-web protoc
plugin (see https://github.com/grpc/grpc-web). It outputs the JsInfo 
provider from https://github.com/aspect-build/rules_js.

## Example usage
```
load("@grpc_web_proto_library//:defs.bzl", "grpc_web_proto_library")
load("@rules_proto//proto:defs.bzl", "proto_library")

proto_library(
    name = "example_proto",
    srcs = [
        "example.proto",
    ],
    visibility = ["//visibility:public"],
    deps = ["@com_google_protobuf//:empty_proto"],
)

grpc_web_proto_library(
    name = "example_grpc_web_proto",
    proto = ":example_proto",
    visibility = ["//visibility:public"],
)
```