(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*             Damien Doligez, projet Para, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1998 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

let ignore_sigint_spec =
  let f () =
    try ignore (Sys.(signal sigint Signal_ignore))
    with Invalid_argument _ -> ()
  in
  "-ignore-sigint",
  Arg.Unit f,
  " Ignore SIGINT, useful when invoked from editor"

let version_spec =
  Printf.sprintf "The Merlin toolkit version %s, for Ocaml %s"
    My_config.version Sys.ocaml_version

let print_version_spec =
  let f () =
    print_endline version_spec;
    exit 0
  in
  "-version",
  Arg.Unit f,
  " Print version and exit"

let print_version_num_spec =
  let f () =
    Printf.printf "%s\n" My_config.version;
    exit 0
  in
  "-vnum",
  Arg.Unit f,
  " Print version number and exit"

let warn_help_spec =
  "-warn-help",
  Arg.Unit Warnings.help_warnings,
  " Show description of warning numbers"

let chosen_protocol = ref None

let protocol_spec =
  "-protocol",
  Arg.String (fun p -> chosen_protocol := Some p),
  " Select frontend protocol (or 'help' to list)"

let syntax_check = ref None

let syntax_check_spec =
  "-syntax-check",
  Arg.String (fun file -> syntax_check := Some file),
  "<filename> Check the given file's syntax"

let unexpected_argument s =
  failwith ("Unexpected argument: " ^ s)

let ignore_non_parametrized =
  List.map (fun x -> x, Arg.Unit ignore, " Ignored (ocaml compatility)") [
    "-a"; "-absname"; "-alias-deps"; "-annot"; "-app-funct"; "-bin-annot";
    "-c"; "-compact"; "-compat-32"; "-config"; "-custom"; "-dalloc";
    "-dclambda"; "-dcmm"; "-dcombine"; "-dcse"; "-dflambda";
    "-dflambda-no-invariants"; "-dflambda-verbose"; "-dinstr"; "-dinterf";
    "-dlambda"; "-dlinear"; "-dlive"; "-dparsetree"; "-dprefer";
    "-drawclambda"; "-drawflambda"; "-drawlambda"; "-dreload"; "-dscheduling";
    "-dsel"; "-dsource"; "-dspill"; "-dsplit"; "-dstartup"; "-dtimings";
    "-dtypedtree"; "-dtypes"; "-dump-pass"; "-fno-PIC"; "-fPIC"; "-g"; "-i";
    "-inlining-report"; "-keep-docs"; "-keep-docs"; "-keep-locs"; "-linkall";
    "-make_runtime"; "-make-runtime"; "-modern"; "-no-alias-deps"; "-noassert";
    "-noautolink"; "-no-check-prims"; "-nodynlink"; "-no-float-const-prop";
    "-no-keep-locs"; "-no-principal"; "-no-rectypes"; "-no-strict-formats";
    "-no-strict-sequence"; "-no-unbox-free-vars-of-clos";
    "-no-unbox-specialised-args"; "-O2"; "-O3"; "-Oclassic"; "-opaque";
    "-output-complete-obj"; "-output-obj"; "-p"; "-pack";
    "-remove-unused-arguments"; "-S"; "-shared"; "-unbox-closures"; "-v";
    "-verbose"; "-where";
  ]

let ignore_parametrized =
  List.map (fun x -> x, Arg.String ignore, " Ignored (ocaml compatility)") [
    "-cc"; "-cclib"; "-ccopt"; "-color"; "-dflambda-let"; "-dllib"; "-dllpath";
    "-for-pack"; "-impl"; "-inline-alloc-cost"; "-inline-branch-cost";
    "-inline-branch-factor"; "-inline-call-cost"; "-inline-indirect-cost";
    "-inline-lifting-benefit"; "-inline-max-depth"; "-inline-max-unroll";
    "-inline"; "-inline-prim-cost"; "-inline-toplevel"; "-intf";
    "-intf_suffix"; "-intf-suffix"; "-o"; "-rounds"; "-runtime-variant";
    "-unbox-closures-factor"; "-use-prims"; "-use_runtime"; "-use-runtime";
  ]

let flags =
  List.concat [
    [
      ignore_sigint_spec;
      print_version_spec;
      print_version_num_spec;
      syntax_check_spec;
      warn_help_spec;
      protocol_spec;
    ];
    ignore_non_parametrized;
    ignore_parametrized;
    Clflags.arg_spec;
  ]

let () =
  (* Parse arguments on commandline *)
  Arg.parse flags
    unexpected_argument
    "Usage: ocamlmerlin [options]\noptions are:"

let chosen_protocol = !chosen_protocol
let syntax_check = !syntax_check
