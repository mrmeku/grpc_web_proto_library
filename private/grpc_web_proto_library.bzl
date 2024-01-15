load("@aspect_rules_js//js:providers.bzl", "JsInfo", "js_info")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@rules_proto//proto:defs.bzl", "ProtoInfo")

def _get_proto_import_paths(proto_info):
    source_root = proto_info.proto_source_root
    if "." == source_root:
        return [src.path for src in proto_info.direct_sources]

    offset = len(source_root) + 1  # + '/'.

    import_paths = []
    for src in proto_info.direct_sources:
        import_paths.append(src.path[offset:])
    return import_paths

def _create_protoc_command(proto_info, ctx):
    protoc_command = "%s" % (ctx.executable._protoc.path)
    protoc_command += " --plugin=protoc-gen-js=%s" % (ctx.executable._protoc_gen_js.path)
    protoc_command += " --plugin=protoc-gen-grpc-web=%s" % (ctx.executable._protoc_gen_grpc_web.path)

    protoc_output_dir = paths.join(ctx.bin_dir.path, ctx.label.workspace_root)
    protoc_command += " --grpc-web_out=import_style=commonjs+dts,mode=grpcwebtext:%s" % (protoc_output_dir)
    protoc_command += " --js_out=import_style=commonjs,binary:%s" % (protoc_output_dir)

    descriptor_sets_paths = [desc.path for desc in proto_info.transitive_descriptor_sets.to_list()]
    protoc_command += " --descriptor_set_in=\"%s\"" % (ctx.configuration.host_path_separator.join(descriptor_sets_paths))

    proto_import_paths = _get_proto_import_paths(proto_info)
    for import_path in proto_import_paths:
        protoc_command += " %s" % import_path

    return protoc_command

def _create_post_process_command(ctx, sources):
    command = ctx.executable._post_process.path + " "
    for output in sources:
        command += " {}".format(output.short_path)
    return command

def _declare_outputs(proto_info, ctx):
    outputs = struct(
        sources = [],
        declarations = [],
    )
    for direct_source in proto_info.direct_sources:
        filename_prefix = direct_source.basename[:-len(direct_source.extension) - 1]
        for filename_suffix in ["_pb", "_grpc_web_pb"]:
            filename = filename_prefix + filename_suffix
            outputs.sources.append(
                ctx.actions.declare_file(filename + ".js"),
            )
            outputs.declarations.append(
                ctx.actions.declare_file(filename + ".d.ts"),
            )

    return outputs

def _grpc_web_proto_library_aspect(target, ctx):
    proto_info = target[ProtoInfo]
    outputs = _declare_outputs(proto_info, ctx)
    protoc_outputs = outputs.declarations + outputs.sources

    tools = []
    tools.extend(ctx.files._protoc)
    tools.extend(ctx.files._protoc_gen_grpc_web)
    tools.extend(ctx.files._protoc_gen_js)
    tools.extend(ctx.files._post_process)

    ctx.actions.run_shell(
        inputs = depset(
            direct = proto_info.direct_sources + proto_info.transitive_descriptor_sets.to_list(),
            transitive = [depset(ctx.files._well_known_protos)],
        ),
        outputs = protoc_outputs,
        command = " && ".join([
            _create_protoc_command(proto_info, ctx),
            _create_post_process_command(ctx, outputs.sources),
        ]),
        tools = depset(tools),
        env = {
            "BAZEL_BINDIR": ctx.bin_dir.path,
        },
    )

    transitive_declarations = []
    transitive_sources = []
    for dep in ctx.rule.attr.deps:
        aspect_data = dep[JsInfo]
        transitive_declarations.append(aspect_data.declarations)
        transitive_declarations.append(aspect_data.transitive_declarations)
        transitive_sources.append(aspect_data.sources)
        transitive_sources.append(aspect_data.transitive_sources)

    return js_info(
        declarations = depset(outputs.declarations),
        sources = depset(outputs.sources),
        transitive_declarations = depset(transitive = transitive_declarations),
        transitive_sources = depset(transitive = transitive_sources),
    )

grpc_web_proto_library_aspect = aspect(
    implementation = _grpc_web_proto_library_aspect,
    attr_aspects = ["deps"],
    attrs = {
        "_post_process": attr.label(
            executable = True,
            cfg = "exec",
            allow_files = True,
            default = Label("@grpc_web_proto_library//private:post_process"),
        ),
        "_protoc": attr.label(
            allow_single_file = True,
            executable = True,
            cfg = "exec",
            default = Label("@com_google_protobuf//:protoc"),
        ),
        "_protoc_gen_grpc_web": attr.label(
            allow_files = True,
            executable = True,
            cfg = "exec",
            default = Label("@com_github_grpc_grpc_web//javascript/net/grpc/web/generator:protoc-gen-grpc-web"),
        ),
        "_protoc_gen_js": attr.label(
            allow_files = True,
            executable = True,
            cfg = "exec",
            default = Label("@com_google_protobuf_javascript//generator:protoc-gen-js"),
        ),
        "_well_known_protos": attr.label(
            default = "@com_google_protobuf//:well_known_type_protos",
            allow_files = True,
        ),
    },
)

def _grpc_web_proto_library_impl(ctx):
    return [
        DefaultInfo(files = ctx.attr.proto[JsInfo].declarations),
        ctx.attr.proto[JsInfo],
    ]

grpc_web_proto_library = rule(
    attrs = {
        "proto": attr.label(
            allow_single_file = True,
            aspects = [grpc_web_proto_library_aspect],
            mandatory = True,
            providers = [ProtoInfo],
        ),
        "_protoc": attr.label(
            allow_single_file = True,
            cfg = "exec",
            default = Label("@com_google_protobuf//:protoc"),
            executable = True,
        ),
        "_protoc_gen_grpc_web": attr.label(
            allow_files = True,
            cfg = "exec",
            default = Label("@com_github_grpc_grpc_web//javascript/net/grpc/web/generator:protoc-gen-grpc-web"),
            executable = True,
        ),
        "_protoc_gen_js": attr.label(
            allow_files = True,
            executable = True,
            cfg = "exec",
            default = Label("@com_google_protobuf_javascript//generator:protoc-gen-js"),
        ),
        "_well_known_protos": attr.label(
            allow_files = True,
            default = "@com_google_protobuf//:well_known_type_protos",
        ),
    },
    implementation = _grpc_web_proto_library_impl,
)
