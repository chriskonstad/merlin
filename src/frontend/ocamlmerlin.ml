(* {{{ COPYING *(

  This file is part of Merlin, an helper for ocaml editors

  Copyright (C) 2013 - 2015  Frédéric Bour  <frederic.bour(_)lakaban.net>
                             Thomas Refis  <refis.thomas(_)gmail.com>
                             Simon Castellan  <simon.castellan(_)iuwt.fr>

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  The Software is provided "as is", without warranty of any kind, express or
  implied, including but not limited to the warranties of merchantability,
  fitness for a particular purpose and noninfringement. In no event shall
  the authors or copyright holders be liable for any claim, damages or other
  liability, whether in an action of contract, tort or otherwise, arising
  from, out of or in connection with the software or the use or other dealings
  in the Software.

)* }}} *)

open Std

(** # Merlin's pipeline
  *
  * The toplevel read and write JSON objects on stdin/stdout
  * Each read object corresponds to a command in the following format:
  *   ["command_name",arg1,arg2]
  * Arguments are command-specific. The ["help"] command list existing
  * commands.
  * The type of answer is also command-specific following this convention:
  * - ["return",result]
  *   the command executed successfully, returning `result' json object
  * - ["error",e]
  *   the command was not able to do it's job, for instance due to wrong
  *   assumptions, missing files, etc.
  * - ["failure",string]
  *   the command was not invoked correctly (for instance, trying to
  *   execute unknown command, or passing invalid arguments, etc)
  * - ["exception",string]
  *   something bad or unexpected happened, this is probably a bug and
  *   should have been caught as either an error or a failure.
  *   Please report!
  *
  * ## Overview
  *
  * Normal usage relies on the "tell" command, whose parameter is
  * source code:
  *   > ["tell","struct","let foo = 42"]  ; send buffer content
  *   < ["return","false"]
  *   > ["tell","struct",null]            ; signal end-of-buffer
  *   < ["return","true"]
  * The command ["seek","before",{"line":int,"col":int}] moves the cursor.
  * A session is a sequence of tell/seek commands to synchronize the
  * buffer and the editor, and of query commands.
  *
  * ## Incremental analysis
  *
  * The source code analysis pipeline is as follows:
  *   outline_lexer | outline_parser | chunk_parser | typer
  * Modulo some implementation details, we have:
  *   outline_lexer  : Lexing.buffer -> Raw_parser.token
  *   outline_parser : Raw_parser.token -> Outline_utils.kind * Raw_parser.token list
  *   chunk_parser   : Outline_utils.kind * Raw_parser.token list -> Parsetree.structure
  *   typer          : Parsetree.structure -> Env.t * Typedtree.structure
  *
  * Incremental update of those analyses is implemented through the
  * History.t data. Such an history is a list zipper, the cursor
  * position marking the split between "past", "present" and
  * "potential future".
  * The "past" is the list of already-validated definitions (you may
  * think of the highlighted code in Coqide/ProofGeneral), with the
  * element at the left of the cursor being the last wellformed definition.
  * The "potential future" is a list of definitions that have already
  * been validated, but will be invalidated and thrown out if the
  * definition under the cursor changes.
  *)

module My_config = My_config
module IO_sexp = IO_sexp

let signal sg behavior =
  try ignore (Sys.signal sg behavior)
  with Invalid_argument _ (*Sys.signal: unavailable signal*) -> ()

let rec on_read ~timeout fd =
  try match Unix.select [fd] [] [] timeout with
    | [], [], [] ->
      if Command.dispatch IO.default_context Protocol.(Query Idle_job) then
        on_read ~timeout:0.0 fd
      else
        on_read ~timeout:(-1.0) fd
    | _, _, _ -> ()
  with
  | Unix.Unix_error (Unix.EINTR, _, _) ->
    on_read ~timeout fd
  | exn -> Logger.log "main" "on_read" (Printexc.to_string exn)

let main_loop () =
  let input, output as io = IO.(lift (make ~on_read:(on_read ~timeout:0.050)
                                        ~input:Unix.stdin ~output:Unix.stdout))
    in
  try
    while true do
      let notifications = ref [] in
      let answer =
        Logger.with_editor notifications @@ fun () ->
        try match Stream.next input with
          | Protocol.Request (context, request) ->
            Protocol.Return
              (request, Command.dispatch context request)
        with
        | Stream.Failure as exn -> raise exn
        | exn -> Protocol.Exception exn
      in
      let notifications = List.rev !notifications in
      try output ~notifications answer
       with exn -> output ~notifications (Protocol.Exception exn);
    done
  with Stream.Failure -> ()

(* Syntax check the file at the given file path *)
exception Unexpected_output
let syntax_check file =
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
  let input, output as io = IO.(lift (memory_make
                                               ~input:(Batteries.IO.input_string command)
                                               ~output:out_buf))
  in
  try
    while true do
      let notifications = ref [] in
      let answer =
        Logger.with_editor notifications @@ fun () ->
        try match Stream.next input with
          | Protocol.Request (context, request) ->
            Protocol.Return
              (request, Command.dispatch context request)
        with
        | Stream.Failure as exn -> raise exn
        | exn -> Protocol.Exception exn
      in
      let notifications = List.rev !notifications in
      try output ~notifications answer
       with exn -> output ~notifications (Protocol.Exception exn);
    done
  with Stream.Failure ->
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
          let errors = (Json.Util.member "value" obj) |> Json.Util.to_list in
          List.iter ~f:(fun e ->
              let member = Json.Util.member in
              let line = member "start" e |> member "line" |> Json.to_string in
              let msg = member "message" e |> Json.to_string in
              let len = String.length msg in
              let clean_msg = String.sub msg 1 (len - 2) |> (* Remove quotes *)
                              Str.global_replace (Str.regexp "\\\\n") "." |>
                              Str.global_replace (Str.regexp "[ \t]+") " " in
              Batteries.IO.nwrite formatted_output file;
              Batteries.IO.write formatted_output ':';
              Batteries.IO.nwrite formatted_output line;
              Batteries.IO.write formatted_output ':';
              Batteries.IO.nwrite formatted_output clean_msg;
              Batteries.IO.write formatted_output '\n';
            ) errors;
          Batteries.IO.nwrite Batteries.IO.stdout (Batteries.IO.close_out formatted_output)
      )
    | _ -> raise Unexpected_output

let () =
  (* Setup signals, unix is a disaster *)
  signal Sys.sigusr1 Sys.Signal_ignore;
  signal Sys.sigpipe Sys.Signal_ignore;
  signal Sys.sighup  Sys.Signal_ignore;
  (* Select frontend *)
  Option.iter Main_args.chosen_protocol ~f:IO.select_frontend;

  (* Setup env for extensions *)
  Unix.putenv "__MERLIN_MASTER_PID" (string_of_int (Unix.getpid ()));

  (* Setup sturgeon monitor *)
  let monitor = Sturgeon_stub.start Command.monitor in

  (* Run! *)
  (* If given a file to syntax check, then check it.  Otherwise run *)
  (* interactively. *)
  match Main_args.syntax_check with
  | None -> main_loop ();
  | Some(file) -> syntax_check file;

  Sturgeon_stub.stop monitor;
  ()
