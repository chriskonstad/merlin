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

val latest_version : Protocol.protocol_version
val current_version : Protocol.protocol_version ref

(* A protocol read & write a stream of Json-like objects *)
    (* Untyped stream *)
type low_io = Json.json Stream.t * (Json.json -> unit)
    (* Protocol-typed stream *)
type io = Protocol.request Stream.t *
  (notifications:(Logger.section * string) list -> Protocol.response -> unit)

(* Generate an in-memory maker, which is a maker that can operate without
   a file *)
type 'a memory_maker =
  fmt:(string -> string, unit, string) format ->
  input:Batteries.IO.input ->
  output:'a Batteries.IO.output ->
  low_io

(* Initialize an in-memory protocol codec *)
val buffered_make : string memory_maker
val unit_make : unit memory_maker

(* Initialize protocol codec from a input and an output channel *)
val make : unit memory_maker

(* Add types *)
val lift : low_io -> io

val register_protocol : name:string -> desc:string -> unit memory_maker -> unit
val select_frontend : string -> unit

(* Misc *)
val default_context : Protocol.Context.t
val invalid_arguments : unit -> 'a
val with_location : ?skip_none:bool -> Location.t -> (string * Json.json) list -> Json.json

module Protocol_io : sig
  val optional_position : Json.json list -> Merlin_source.position option
  val mandatory_position : Json.json list -> Merlin_source.position
end
