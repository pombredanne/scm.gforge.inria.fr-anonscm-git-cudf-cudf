(*****************************************************************************)
(*  libCUDF - CUDF (Common Upgrade Description Format) manipulation library  *)
(*  Copyright (C) 2009  Stefano Zacchiroli <zack@pps.jussieu.fr>             *)
(*                                                                           *)
(*  This library is free software: you can redistribute it and/or modify     *)
(*  it under the terms of the GNU Lesser General Public License as           *)
(*  published by the Free Software Foundation, either version 3 of the       *)
(*  License, or (at your option) any later version.  A special linking       *)
(*  exception to the GNU Lesser General Public License applies to this       *)
(*  library, see the COPYING file for more information.                      *)
(*****************************************************************************)

open ExtLib
open OUnit
open Printf

open Cudf_types
open Cudf

let cudf_test_path name = sprintf "./tests/%s.cudf" name

let good_cudfs = [	(* CUDF whose parsing must suceed *)
]
let bad_cudfs = [	(* CUDF whose parsing must fail *)
]
let consistent_univs = [	(* CUDF whose status is expected to be consistent *)
  "assert-true" ;
]
let inconsistent_univs = [	(* CUDF whose status has some broken dep *)
  "assert-false" ;
]
let good_pkgs = [	(* universes whose parsing must suceed *)
  "conflict-comma-sep" ;
  "plus-in-pkgname" ;
]
let bad_pkgs = [	(* universes whose parsing must fail *)
]
let good_prob_sol = [	(* pairs cudf/sol, with sol being a good solution *)
  "legacy", "legacy-sol" ;
  "fresher", "fresher-sol-good" ;
  "upgrade-singleton", "upgrade-singleton-sol-good" ;
  "keep", "keep-sol-good";
  "virt-upgrade", "virt-upgrade-sol-good";
]
let bad_prob_sol = [	(* pairs cudf/sol, with sol being a bad solution *)
  "fresher", "fresher-sol-bad" ;
  "upgrade-singleton", "upgrade-singleton-sol-bad" ;
  "keep", "keep-sol-bad";
  "keep", "keep-sol-bad2";
  "keep", "keep-sol-bad3";
  "virt-upgrade", "virt-upgrade-sol-bad";
  "virt-upgrade", "virt-upgrade-sol-bad2";
  "virt-upgrade", "virt-upgrade-sol-bad3";
]

(** {5 Helpers} *)

(** {6 OUnit helpers}
    i.e., missing stuff which should better be integrated into OUnit *)

let assert_no_exn f = assert_equal true (try f () ; true with _ -> false)
let assert_exn f = assert_equal true (try f () ; false with _ -> true)

let assert_raises' ?(cmp = (=)) ~exn f =
  assert_equal true (try f () ; false with exn' -> cmp exn exn')

(** {6 CUDF helpers} *)

let parse_test ~parse_fun name =
  let ic = open_in (cudf_test_path name) in
  let p = Cudf_parser.from_in_channel ic in
  let out = parse_fun p in
  close_in ic;
  out

let parse_cudf_wrapper p =
  match Cudf_parser.parse p with
    | pre, pkgs, Some req -> pre, pkgs, req
    | pre, pkgs, None -> raise (Cudf_parser.Parse_error ("", dummy_loc))
let parse_pkgs_wrapper p =
  match Cudf_parser.parse p with
    | pre, pkgs, Some req -> raise (Cudf_parser.Parse_error ("", dummy_loc))
    | pre, pkgs, None -> pkgs
let load_cudf_wrapper p =
  match Cudf_parser.load p with
    | pre, pkgs, Some req -> pre, pkgs, req
    | pre, pkgs, None -> raise (Cudf_parser.Parse_error ("", dummy_loc))
let load_pkgs_wrapper p =
  match Cudf_parser.load p with
    | pre, pkgs, Some req -> raise (Cudf_parser.Parse_error ("", dummy_loc))
    | pre, pkgs, None -> pkgs

let parse_cudf_test = parse_test ~parse_fun:parse_cudf_wrapper
let parse_pkgs_test = parse_test ~parse_fun:parse_pkgs_wrapper
let load_cudf_test = parse_test ~parse_fun:load_cudf_wrapper
let load_univ_test = parse_test ~parse_fun:load_pkgs_wrapper

(** {5 Test builders} *)

let good_parse ~parse_fun name = TestCase (fun _ ->
  assert_no_exn (fun () -> parse_test ~parse_fun name))

let bad_parse ~parse_fun name = TestCase (fun _ ->
  assert_raises'
    ~cmp:(fun e1 e2 ->
	    match e1, e2 with
	      | Cudf_parser.Parse_error _, Cudf_parser.Parse_error _ -> true
	      | _ -> false)
    ~exn:(Cudf_parser.Parse_error ("", dummy_loc))
    (fun () -> parse_test ~parse_fun name))

let good_solution prob_name sol_name = TestCase (fun _ ->
  let (_,univ,req), sol = load_cudf_test prob_name, load_univ_test sol_name in
    sprintf "problem with correct solution: (%s,%s)" prob_name sol_name @?
    fst (Cudf_checker.is_solution (univ,req) sol))

let bad_solution prob_name sol_name = TestCase (fun _ ->
  let (_,univ,req), sol = load_cudf_test prob_name, load_univ_test sol_name in
    sprintf "problem with correct solution: (%s,%s)" prob_name sol_name @?
    not (fst (Cudf_checker.is_solution (univ,req) sol)))

(** {5 Test suites} *)

(** {6 Big suites} *)

let good_cudf_parse_suite =
  "parsing of good CUDFs" >::: List.map
      (fun n -> n >: good_parse ~parse_fun:parse_cudf_wrapper n)
      good_cudfs

let bad_cudf_parse_suite =
  "parsing of bad CUDFs" >::: List.map
      (fun n -> n >: bad_parse ~parse_fun:parse_cudf_wrapper n)
      bad_cudfs

let good_pkgs_parse_suite =
  "parsing of good package universes" >::: List.map
      (fun n -> n >: good_parse ~parse_fun:parse_pkgs_wrapper n)
      good_pkgs

let bad_pkgs_parse_suite =
  "parsing of bad package universes" >::: List.map
      (fun n -> n >: bad_parse ~parse_fun:parse_pkgs_wrapper n)
      bad_pkgs

(** {6 Regression tests} *)

let value_parse_suite =
  let value_parse_ok (desc, typ, s, v) = desc >: TestCase (fun _ ->
    assert_equal (Cudf_types_pp.parse_value typ s) v) in
  let value_parse_ko (desc, typ, s) = desc >: TestCase (fun _ ->
    assert_raises'
      ~cmp:(fun e1 e2 ->
	      match e1, e2 with
		| Cudf_types_pp.Type_error _, Cudf_types_pp.Type_error _ -> true
		| _ -> e1 = e2)
      ~exn:(Cudf_types_pp.Type_error (`Int, `Int ~-1))
      (fun () -> Cudf_types_pp.parse_value typ s))
  in
  "value parsing" >::: [
    "good" >::: List.map value_parse_ok [
      "int 1", `Int, "1", `Int 1 ;
      "int -1", `Int, "-1", `Int ~-1 ;
      "posint", `Posint, "1", `Posint 1 ;
      "nat 0", `Nat, "0", `Nat 0 ;
      "bool true", `Bool, "true", `Bool true ;
      "bool false", `Bool, "false", `Bool false ;
      "string", `String, "asfkjg 1%!@$% aaa", `String "asfkjg 1%!@$% aaa" ;
      "pkgname", `Pkgname, "foo", `Pkgname "foo" ;
      "pkgname /", `Pkgname, "/bin/bash", `Pkgname "/bin/bash" ;
      "pkgname @", `Pkgname, "libfoo@bar", `Pkgname "libfoo@bar" ;
      "pkgname ()", `Pkgname, "libfoo(bar)", `Pkgname "libfoo(bar)" ;
      "ident", `Ident, "foo", `Ident "foo" ;
      "ident -", `Ident, "foo-bar", `Ident "foo-bar" ;
      "ident num", `Ident, "foo12", `Ident "foo12" ;
      "enum", `Enum ["foo";"bar";"baz"], "foo",
        `Enum(["foo";"bar";"baz"], "foo") ;
      "keep", keep_type, "feature", `Enum (keep_enums, "feature") ;
      "vpkg dumb", `Vpkg, "foo", `Vpkg ("foo", None) ;
      "vpkg", `Vpkg, "foo > 1", `Vpkg ("foo", Some (`Gt, 1)) ;
      "fmla vpkg", `Vpkgformula, "foo", `Vpkgformula [["foo", None]] ;
      "fmla true", `Vpkgformula, "true!", `Vpkgformula [] ;
      "fmla false", `Vpkgformula, "false!", `Vpkgformula [ [] ] ;
      "fmla and", `Vpkgformula, "foo, bar > 1",
        `Vpkgformula [ ["foo", None] ; ["bar", Some (`Gt, 1)] ] ;
      "fmla or", `Vpkgformula, "foo < 7 | bar",
        `Vpkgformula [ ["foo", Some (`Lt, 7) ; "bar", None] ] ;
      "fmla cnf", `Vpkgformula, "foo | bar, quux | baz | sup",
        `Vpkgformula [ ["foo",None; "bar",None] ;
		       ["quux",None; "baz",None; "sup",None] ] ; 
      "vpkgs nil", `Vpkglist, "", `Vpkglist [] ;
      "vpkgs one", `Vpkglist, "foo", `Vpkglist ["foo", None] ;
      "vpkgs cons", `Vpkglist, "foo != 1, bar",
        `Vpkglist [ "foo", Some (`Neq, 1) ; "bar", None ] ;
      "veqpkg", `Veqpkg, "foo = 7", `Veqpkg ("foo", Some (`Eq, 7)) ;
      "veqpkgs", `Veqpkglist, "foo = 7", `Veqpkglist [("foo", Some (`Eq, 7))] ;
      "typedecl", `Typedecl, "foo: vpkgformula = [ foo, bar | baz ]",
        `Typedecl ["foo",
		   `Vpkgformula (Some [["foo",None];["bar",None;"baz",None]])] ;
      "typedecls", `Typedecl, "foo: int, bar: string = [\"baz quux\"]",
        `Typedecl ["foo", `Int None ; "bar", `String (Some "baz quux")] ;
      "typedecl enum", `Typedecl, "p: enum[a,b,c]",
        `Typedecl ["p", `Enum (["a"; "b"; "c"], None)] ;
      "typedecl enum def", `Typedecl, "p: enum[a,b,c] = [a]",
        `Typedecl ["p", `Enum (["a"; "b"; "c"], Some "a")] ;
      "typedecl pkgname ident", `Typedecl, "p: pkgname = [ pkg ]",
        `Typedecl ["p", `Pkgname (Some "pkg")] ;
      "typedecl pkgname int", `Typedecl, "p: pkgname = [ 1 ]",
        `Typedecl ["p", `Pkgname (Some "1")] ;
      "typedecl vpkg ident", `Typedecl, "p: vpkg = [ pkg ]",
        `Typedecl ["p", `Vpkg (Some ("pkg", None))] ;
      "typedecl vpkg int", `Typedecl, "p: vpkg = [ 1 ]",
        `Typedecl ["p", `Vpkg (Some ("1", None))] ;
      "typedecl veqpkg int", `Typedecl, "p: veqpkg = [ 1 ]",
        `Typedecl ["p", `Veqpkg (Some ("1", None))] ;
      "typedecl vpkgs ident", `Typedecl, "l: vpkglist = [ pkg ]",
        `Typedecl ["l", `Vpkglist (Some [("pkg", None)])] ;
      "typedecl vpkgs int", `Typedecl, "l: vpkglist = [ 1 ]",
        `Typedecl ["l", `Vpkglist (Some [("1", None)])] ;
      "typedecl veqpkgs int", `Typedecl, "l: veqpkglist = [ 1 ]",
        `Typedecl ["l", `Veqpkglist (Some [("1", None)])] ;
    ] ;
    "bad" >::: List.map value_parse_ko [
      "int garbage", `Int, "78 gotcha" ;
      "posint neg", `Posint, "-1" ;
      "posint zero", `Posint, "0" ;
      "nat neg", `Nat, "-1" ;
      "bool", `Bool, "xxx" ;
      "bool", `Bool, "foo" ;
      "bool garbage", `Bool, "true gotcha" ;
      "string \\n", `String, "foo\nbar" ;
      "string \\r", `String, "foo\rbar" ;
      "pkgname !", `Pkgname, "foo!bar" ;
      "pkgname !", `Pkgname, "foo!bar" ;
      "ident numstart", `Ident, "12foo" ;
      "ident caps", `Ident, "foAo" ;
      "ident symb", `Ident, "fo/o" ;
      "enum", `Enum ["foo"], "bar" ;
      "keep", keep_type, "foo" ;
      "empty fmla", `Vpkgformula, "" ;
      "vpkg garbage", `Vpkg, "foo > 1 gotcha" ;
      "vpkgs trail", `Vpkglist, "foo ," ;
      "veqpkg", `Veqpkg, "foo > 1" ;
      "enum bad def", `Typedecl, "p: enum[a,b,c] = [z]" ;
    ] ;
  ]

let misc_parse_suite =
  "misc parsing" >::: [
    "qstring" >::: [
      "base" >:: (fun () ->
        assert_equal (Cudf_types_pp.parse_qstring "\"foo\"") "foo") ;
      "escape \"" >:: (fun () ->
        assert_equal (Cudf_types_pp.parse_qstring "\"fo\\\"o\"") "fo\"o") ;
      "escape \\" >:: (fun () ->
        assert_equal (Cudf_types_pp.parse_qstring "\"fo\\\\o\"") "fo\\o") ;
      "dangling \"" >:: (fun () -> "unexpected parse success" @?
        (try ignore (Cudf_types_pp.parse_qstring "\"fo\"o\"") ; false
	 with _ -> true)) ;
      "typename ident" >:: (fun () ->
        assert_equal (Cudf_types_pp.parse_type "ident") `Ident) ;
    ]
  ]

let or_dep =
  "disjunctive dependencies" >:: (fun () ->
    assert_equal
      (lookup_package (load_univ_test "or-dep") ("electric-engine", 1)).depends
      [["solar-collector", None; "huge-battery", None]])

let parse_reg_suite =
  "regression tests - parsing" >::: [
    or_dep ;
  ]

(** {6 New feature tests}
    i.e., kinda test-driven development *)

let status_filtering =
  "status projection" >:: (fun () ->
    "status projection returned an \"installed: false\" package" @?
      let _, univ, _ = load_cudf_test "legacy" in
      List.for_all
        (fun { installed = i } -> i)
        (get_packages (status univ)))

let inst_version_lookup =
  "lookup installed versions" >:: (fun () ->
    let univ = load_univ_test "multi-versions" in
    let versions pkg = List.map (fun p -> p.version) (get_installed univ pkg) in
      assert_equal (List.sort (versions "gasoline-engine")) [1; 2];
      assert_equal (versions "battery") [3];
      assert_equal (versions "not-installed") [];
      assert_equal (versions "not-existent") [])

let mem_installed =
  "check whether an installation satisfy a package constraint" >:: (fun () ->
    let _, univ, _ = load_cudf_test "legacy" in
    let mem = mem_installed ~include_features:true univ in
    let mem' = mem_installed ~include_features:false univ in
      "'car' unsatisfied" @? mem ("car", None);
      "'car = 1' unsatisfied" @? mem ("car", Some (`Eq, 1));
      "'car > 1' satisfied'" @? not (mem ("car", Some (`Gt, 1)));
      "'car >= 1' unsatisfied" @? mem ("car", Some (`Leq, 1));
      "'engine' unsatisfied w features" @? mem ("engine", None);
      "'engine' satisfied w/o features" @? not (mem' ("engine", None));
  )

let satisfy_formula =
  "check formula satisfaction" >:: (fun () ->
    let _, univ, _ = load_cudf_test "legacy" in
    let sat f = fst (Cudf_checker.satisfy_formula univ f) in
      "true unsatisfied (WTF?)" @? sat [];
      "conjunction unsatisfied" @? sat [["battery", None]; ["wheel", None]];
      "disjunction unsatisfied" @?
	sat [["solar-collector", None; "wheel", None]];
      "unsat formula satisfied" @?
	not (sat [["wheel", Some (`Gt, 2); "tire", None]]);
  )

let disjoint =
  "check package disjunction (i.e., conflicts)" >:: (fun () ->
    let _, univ, _ = load_cudf_test "legacy" in
    let disj ps = fst (Cudf_checker.disjoint univ ps) in
      "missing package reported as existing" @? disj ["fubar", None];
      "undetected conflict" @? not (disj ["door", Some (`Eq, 1)]);
      "undetected partial conflict" @?
	not (disj ["door", Some (`Gt, 1); "turbo", None]);
  )

let self_conflicts =
  "check self-conflicts" >:: (fun () ->
    let consist u = fst (Cudf_checker.is_consistent u) in
      "direct self-conflict" @? consist (load_univ_test "direct-self-conflict");
      "indirect self-conflict" @?
	consist (load_univ_test "indirect-self-conflict"))

let consistency =
  "check universe consistency" >::: [
    "legacy example consistency" >:: (fun () ->
      let _, univ, _ = load_cudf_test "legacy" in
	"inconsistent legacy example" @? fst (Cudf_checker.is_consistent univ))
  ]

let univ_sizes =
  let univ = lazy (let _, univ, _ = load_cudf_test "legacy" in univ) in
    "check universe size measuring" >::: [
      "total size" >::
	(fun () -> assert_equal (universe_size (Lazy.force univ)) 20);
      "installed size" >::
	(fun () -> assert_equal (installed_size (Lazy.force univ)) 6);
    ]

let good_solution_suite = "good solutions" >:::
  List.map (fun (prob, sol) -> good_solution prob sol) good_prob_sol

let bad_solution_suite = "bad solutions" >:::
  List.map (fun (prob, sol) -> bad_solution prob sol) bad_prob_sol

let consistency_suite = "consistent universes" >:::
  List.map
    (fun u -> TestCase (fun () -> "consistent" @?
       fst (Cudf_checker.is_consistent (load_univ_test u))))
    consistent_univs

let inconsistency_suite = "inconsistent universes" >:::
  List.map
    (fun u -> TestCase (fun () -> "inconsistent" @?
       not (fst (Cudf_checker.is_consistent (load_univ_test u)))))
    inconsistent_univs

(** {6 Test suites} *)

let feature_suite =
  "new feature tests" >::: [
    status_filtering ;
    inst_version_lookup ;
    mem_installed ;
    satisfy_formula ;
    disjoint ;
    self_conflicts ;
    consistency ;
    univ_sizes ;
  ]

(*
let test_encode =
  "encode" >:: (fun () ->
    let s = "@/bin/*-+" in
    assert_equal (Cudf_types.encode s) "@/bin/%2a-+"
  )
;;

let test_decode =
  "encode" >:: (fun () ->
    let s = "@/bin/%2a-+" in
    assert_equal (Cudf_types.decode s) "@/bin/*-+"
  )
;;

let encoding_suite =
  "encoding / decoding tests" >::: [
    test_encode;
    test_decode
  ]
*)

(** {5 Assemble and run tests} *)

let all =
  "all tests" >::: [
    value_parse_suite ;
    misc_parse_suite ;
    good_cudf_parse_suite ;
    bad_cudf_parse_suite ;
    good_pkgs_parse_suite ;
    bad_pkgs_parse_suite ;
    consistency_suite ;
    inconsistency_suite ;
    good_solution_suite ;
    bad_solution_suite ;
    parse_reg_suite ;
    feature_suite ;
    (* encoding_suite ; *)
  ]

