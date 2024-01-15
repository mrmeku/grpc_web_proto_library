load("@grpc_web_proto_library//:defs.bzl", "grpc_web_proto_library")
load("@rules_proto//proto:defs.bzl", "proto_library")

proto_library(
    name = "echo_proto",
    srcs = [
        "echo.proto",
    ],
    visibility = ["//visibility:public"],
    deps = ["@com_google_protobuf//:empty_proto"],
)

grpc_web_proto_library(
    name = "echo_grpc_web_proto",
    proto = ":echo_proto",
    visibility = ["//visibility:public"],
)
