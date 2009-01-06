(*****************************************************************************)
(*  libCUDF - CUDF (Common Upgrade Description Format) manipulation library  *)
(*  Copyright (C) 2009  Stefano Zacchiroli <zack@pps.jussieu.fr>             *)
(*                                                                           *)
(*  This program is free software: you can redistribute it and/or modify     *)
(*  it under the terms of the GNU General Public License as published by     *)
(*  the Free Software Foundation, either version 3 of the License, or (at    *)
(*  your option) any later version.                                          *)
(*                                                                           *)
(*  This program is distributed in the hope that it will be useful, but      *)
(*  WITHOUT ANY WARRANTY; without even the implied warranty of               *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU        *)
(*  General Public License for more details.                                 *)
(*                                                                           *)
(*  You should have received a copy of the GNU General Public License        *)
(*  along with this program.  If not, see <http://www.gnu.org/licenses/>.    *)
(*****************************************************************************)

open ExtLib
open Printf

open Cudf

let cudf_arg = ref ""
let univ_arg = ref ""
let sol_arg = ref ""
let dump_arg = ref false

let cudf = ref None
let univ = ref None
let sol = ref None

let arg_spec = [
  "-cudf", Arg.Set_string cudf_arg,
    "parse the given CUDF (universe + request)" ;
  "-univ", Arg.Set_string univ_arg, "parse the given package universe" ;
  "-sol", Arg.Set_string sol_arg, "parse the given problem solution" ;
  "-dump", Arg.Set dump_arg, "dump parse results to standard output" ;
]

let usage_msg =
"Usage: cudf-check [OPTION...]
In particular:
  cudf-check -cudf FILE               validate CUDF
  cudf-check -cudf FILE -sol FILE     validate CUDF and its solution
  cudf-check -univ FILE               validate package universe (no request)
Options:"

let die_usage () = Arg.usage arg_spec usage_msg ; exit 2

let print_inst_info inst =
  let is_consistent, msg = Cudf_checker.is_consistent inst in
    if is_consistent then
      printf "installation: consistent\n%!"
    else
      printf "installation: broken (reason: %s)\n%!" msg

let print_cudf cudf =
  (* TODO dummy implementation, should pretty print here ... *)
  if !dump_arg then
    print_endline (dump cudf)

let print_sol_info inst sol =
  let is_sol, msg = Cudf_checker.is_solution inst sol in
    printf "is_solution: %b%s\n%!" is_sol
      (if is_sol then "" else sprintf " (reason: %s)" msg)

let main () =
  if !cudf_arg <> "" then begin
    try
      let p = Cudf_parser.from_in_channel (open_in !cudf_arg) in
	eprintf "parsing CUDF ...\n%!";
	cudf := Some (Cudf_parser.load_cudf p)
    with
	Cudf_parser.Parse_error _
      | Cudf.Constraint_violation _ as exn ->
	  eprintf "Error while loading CUDF from %s: %s\n%!"
	    !cudf_arg (Printexc.to_string exn);
	  exit 1
  end;
  if !univ_arg <> "" then begin
    try
      let p = Cudf_parser.from_in_channel (open_in !univ_arg) in
	eprintf "parsing package universe ...\n%!";
	univ := Some (Cudf_parser.load_universe p)
    with
	Cudf_parser.Parse_error _
      | Cudf.Constraint_violation _ as exn ->
	  eprintf "Error while loading universe from %s: %s\n%!"
	    !univ_arg (Printexc.to_string exn);
	  exit 1
  end;
  if !sol_arg <> "" then begin
    try
      let p = Cudf_parser.from_in_channel (open_in !sol_arg) in
	eprintf "parsing solution ...\n%!";
	sol := Some (Cudf_parser.load_universe p)
    with
	Cudf_parser.Parse_error _
      | Cudf.Constraint_violation _ as exn ->
	  eprintf "Error while loading solution from %s: %s\n%!"
	    !sol_arg (Printexc.to_string exn);
	  exit 1
  end;
  match !cudf, !univ, !sol with
    | Some cudf, None, None ->
	print_inst_info (fst cudf);
	print_cudf cudf
    | Some cudf, None, Some sol ->
	let sol = Cudf_checker.solution sol in
	  print_inst_info (fst cudf);
	  print_sol_info (fst cudf) sol;
	  print_cudf cudf
    | None, Some univ, None ->
	print_inst_info univ
    | _ -> die_usage ()

let _ = 
  Arg.parse arg_spec ignore usage_msg;
  main()
