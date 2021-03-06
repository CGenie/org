open Mldoc_org
open Mldoc_org.Parser
open Mldoc_org.Config

let ast_to_json ast =
  Type.blocks_to_yojson ast |> Yojson.Safe.to_string

let json_to_ast json =
  Type.blocks_of_yojson json

let generate backend config doc output =
  let export = Exporters.find backend in
  Exporters.run export config doc output

let _ =
  let open Js_of_ocaml in
  Js.export "MldocOrg"
    (object%js
      method parseJson input config_json =
        let config_json = Js.to_string config_json in
        let config_json = Yojson.Safe.from_string config_json in
        match Config.of_yojson config_json with
        | Ok config -> begin
            let str = Js.to_string input in
            parse config str |> ast_to_json |> Js.string
          end
        | Error e ->
          Js_of_ocaml.Js.string ("Config error: " ^ e)

      method parseHtml input config_json =
        let str = Js.to_string input in
        let config_json = Js.to_string config_json in
        let config_json = Yojson.Safe.from_string config_json in
        match Config.of_yojson config_json with
        | Ok config ->
          let ast = parse config str in
          let document = Document.from_ast None ast in
          let buffer = Buffer.create 1024 in
          let _ = Sys_js.set_channel_flusher stdout (fun s ->
              Buffer.add_string buffer s
            ) in
          generate "html" config document stdout;
          Js_of_ocaml.Js.string (Buffer.contents buffer)
        | Error e ->
          Js_of_ocaml.Js.string ("Config error: " ^ e)

      method jsonToHtmlStr input config_json =
        let config_json = Js.to_string config_json in
        let config_json = Yojson.Safe.from_string config_json in
        match Config.of_yojson config_json with
        | Ok config -> begin
            let json_str = Js.to_string input in
            let json = Yojson.Safe.from_string json_str in
            match json_to_ast json with
            | Ok blocks ->
              let buffer = Buffer.create 1024 in
              let _ = Sys_js.set_channel_flusher stdout (fun s ->
                  Buffer.add_string buffer s
                ) in
              let xml_blocks = Html.blocks config blocks in
              let _ = Xml.output_xhtml stdout xml_blocks in
              Js_of_ocaml.Js.string (Buffer.contents buffer)
            | Error e ->
              Js_of_ocaml.Js.string ("Parse error: " ^ e)
          end
        | Error e ->
          Js_of_ocaml.Js.string ("Config error: " ^ e)

      method inlineListToHtmlStr input =
        let json_str = Js.to_string input in
        let json = Yojson.Safe.from_string json_str in
        match Type.inline_list_of_yojson json with
        | Ok inline_list ->
          let buffer = Buffer.create 1024 in
          let _ = Sys_js.set_channel_flusher stdout (fun s ->
              Buffer.add_string buffer s
            ) in
          let _ = Xml.output_xhtml stdout (Html.map_inline inline_list) in
          Js_of_ocaml.Js.string (Buffer.contents buffer)
        | Error e ->
          Js_of_ocaml.Js.string ("parse error: " ^ e)
    end)
