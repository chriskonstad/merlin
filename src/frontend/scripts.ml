open Std
(* Support scripting of the JSON interface using buffers *)
(* Each script should take in whatever arguments it needs
   and return a (maker, handler) tuple).  The handler is used to process
   the store JSON output, which is an array of JSON objects.  Each object
   is the return value of the version 3 protocol for each scripted command.
   The handler is called after all of the scripted commands have been run. *)
exception Unexpected_output

(* This is the type of the (maker, handler) tuple. Note that the handler
   must handle outputting the result. *)
type script_handle = IO.low_io * (unit -> unit)

let syntax_checker file : script_handle =
  match file with
    (* Syntax check the given file *)
    | Some(file) ->
      let quote_quotes s =
        Str.global_replace (Str.regexp "\"") "\\\"" s
      in

      (* Read the file *)
      let f_handle = Batteries.File.open_in file in
      let f_contents = Batteries.IO.read_all f_handle in
      Batteries.IO.close_in f_handle;

      (* Setup a buffer to write to, and script the protocol *)
      let out_buf = Batteries.IO.output_string () in
      Batteries.IO.nwrite out_buf "[{}";
      let command = [
        (* Specify a particular protocol version *)
        "[\"protocol\", \"version\", 3]";
        (* "Checkout" the file, loading any .merlins required *)
        "[\"checkout\", \"auto\", \"" ^ (quote_quotes file) ^ "\"]";
        (* Load the file contents *)
        "[\"tell\", \"start\", \"end\", \"" ^ (quote_quotes f_contents) ^ "\"]";
        (* Query for any errors *)
        "[\"errors\"]";
      ] |> Batteries.List.fold_left (fun cur next ->
          cur ^ next ^ "\n"
        ) "" in
      let maker = (IO.buffered_make ~fmt:", %s"
         ~input:(Batteries.IO.input_string command)
         ~output:out_buf)
      in
      let handler = (fun () ->
          (* Take the original output buffer, read the contents and format the last *)
          (* printed JSON object, because that's the errors. Format the output. *)
          Batteries.IO.write out_buf ']';
          let formatted_output = Batteries.IO.output_string () in
          let output_string = Batteries.IO.close_out out_buf in
          let js_array = Json.from_string output_string in
          match js_array with
          | `List l -> (match List.last l with
              | None -> raise Unexpected_output
              | Some(obj) ->
                let member = Json.Util.member in
                let errors = (member "value" obj) |> Json.Util.to_list in
                List.iter ~f:(fun e ->
                    let line = member "start" e |> member "line" |> Json.to_string in
                    let col = member "start" e |> member "col" |> Json.to_string in
                    let msg = member "message" e |> Json.to_string in
                    let len = String.length msg in
                    let clean_msg = String.sub msg 1 (len - 2) |> (* Remove quotes *)
                                    Str.global_replace (Str.regexp "\\\\n") "." |>
                                    Str.global_replace (Str.regexp "[ \t]+") " " in
                    let output str =
                      Batteries.IO.nwrite formatted_output str; ()
                    in
                    let field_sep = ":" in
                    output file;
                    output field_sep;
                    output line;
                    output field_sep;
                    output col;
                    output field_sep;
                    output clean_msg;
                    output "\n";
                  ) errors;
                Batteries.IO.nwrite Batteries.IO.stdout (Batteries.IO.close_out formatted_output)
            )
          | _ -> raise Unexpected_output
        ) in
      maker, handler
    (* Run the interactive main loop *)
    | None -> let maker = IO.unit_make ~fmt:"%s\n"
                  ~input:Batteries.IO.stdin
                  ~output:Batteries.IO.stdout
      in
      let handler = (fun () -> ()) in
      maker, handler
