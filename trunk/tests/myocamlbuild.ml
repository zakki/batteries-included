open Ocamlbuild_plugin
open Command (* no longer needed for OCaml >= 3.10.2 *)

(**
   {1 OCamlFind}
*)

let run_and_read      = Ocamlbuild_pack.My_unix.run_and_read
    
let blank_sep_strings = Ocamlbuild_pack.Lexers.blank_sep_strings

module OCamlFind =
struct
  (* this lists all supported packages *)
  let find_packages () =
    blank_sep_strings &
      Lexing.from_string &
      run_and_read "ocamlfind list | cut -d' ' -f1"

  (* this is supposed to list available syntaxes, but I don't know how to do it. *)
  let find_syntaxes () = ["camlp4o"; "camlp4r"]

  (* ocamlfind command *)
  let ocamlfind x = S[A"ocamlfind"; x]

  let  before_options () =
    (* by using Before_options one let command line options have an higher priority *)
    (* on the contrary using After_options will guarantee to have the higher priority *)
    
    (* override default commands by ocamlfind ones *)
    Options.ocamlc     := ocamlfind & A"ocamlc";
    Options.ocamlopt   := ocamlfind & A"ocamlopt";
    Options.ocamldep   := ocamlfind & A"ocamldep";
    Options.ocamldoc   := ocamlfind & A"ocamldoc";
    Options.ocamlmktop := ocamlfind & A"ocamlmktop"

  let get_ocamldoc_directory () =
    let ocamldoc_directory = run_and_read "ocamlfind ocamldoc -customdir" in
    let length             = String.length ocamldoc_directory             in
      assert (length != 0);
      let char = ocamldoc_directory.[length - 1] in
	if (char = '\n') || (char = '\r') then String.sub ocamldoc_directory 0 (length - 1)
	else ocamldoc_directory
    
  let after_rules () =
       (* When one link an OCaml library/binary/package, one should use -linkpkg *)
       flag ["ocaml"; "byte";   "link"; "program"] & A"-linkpkg";
       flag ["ocaml"; "native"; "link"; "program"] & A"-linkpkg";


       (* For each ocamlfind package one inject the -package option when
       	* compiling, computing dependencies, generating documentation and
       	* linking. *)
       List.iter begin fun pkg ->
         flag ["ocaml"; "compile";  "pkg_"^pkg] & S[A"-package"; A pkg];
         flag ["ocaml"; "ocamldep"; "pkg_"^pkg] & S[A"-package"; A pkg];
         flag ["ocaml"; "doc";      "pkg_"^pkg] & S[A"-package"; A pkg];
         flag ["ocaml"; "link";     "pkg_"^pkg] & S[A"-package"; A pkg];
       end (find_packages ());

       (* Like -package but for extensions syntax. Morover -syntax is useless
       	* when linking. *)
       List.iter begin fun syntax ->
         flag ["ocaml"; "compile";  "syntax_"^syntax] & S[A"-syntax"; A syntax];
         flag ["ocaml"; "ocamldep"; "syntax_"^syntax] & S[A"-syntax"; A syntax];
         flag ["ocaml"; "doc";      "syntax_"^syntax] & S[A"-syntax"; A syntax];
       end (find_syntaxes ());
       
       (* The default "thread" tag is not compatible with ocamlfind.
          Indeed, the default rules add the "threads.cma" or "threads.cmxa"
          options when using this tag. When using the "-linkpkg" option with
          ocamlfind, this module will then be added twice on the command line.
       
          To solve this, one approach is to add the "-thread" option when using
          the "threads" package using the previous plugin.
        *)
       flag ["ocaml"; "pkg_threads"; "compile"]  (S[A "-thread"]);
       flag ["ocaml"; "pkg_threads"; "link"]     (S[A "-thread"]);
end

(**
   {1 Others}
*)

module Misc =
struct
  let after_rules () =
    flag ["ocaml"; "link"; "byte";   "use_ocamldoc_info"] (S[A "-I"; A "+ocamldoc"; A "odoc_info.cma"]);
    flag ["ocaml"; "link"; "native"; "use_ocamldoc_info"] (S[A "-I"; A "+ocamldoc"(*; A "odoc_info.cmxa"*)]);
    flag ["ocaml"; "docfile";        "use_ocamldoc_info"] (S[A "-I"; A "+ocamldoc"]);
    flag ["ocaml"; "docdir";         "use_ocamldoc_info"] (S[A "-I"; A "+ocamldoc"]);
    flag ["ocaml"; "doc";            "use_ocamldoc_info"] (S[A "-I"; A "+ocamldoc"]);


    (*The command-line for [use_batteries] and [use_batteries_r]*)
    (*let cl_use_batteries = [A"-package"; A "batteries.openin.syntax"; A "-package"; A "batteries"] in*)
    let cl_use_batteries = [A"-package"; A "batteries.pa_openin.syntax,batteries.pa_type_conv.syntax,batteries.pa_where.syntax,batteries.sexplib.syntax,batteries.bin_prot.syntax,sexplib.syntax"; A "-package"; A "batteries"] in
      
    (** Tag [use_batteries] provides both package [batteries]
	and all syntax extensions, in original syntax. *)

    let cl_original = cl_use_batteries @ [A"-syntax";  A "camlp4o"] in
    flag ["ocaml"; "compile";  "use_batteries"] & S cl_original ;
    flag ["ocaml"; "ocamldep"; "use_batteries"] & S cl_original ;
    flag ["ocaml"; "doc";      "use_batteries"] & S cl_original ;
    flag ["ocaml"; "link";     "use_batteries"] & S cl_original ;

    (** Tag [use_batteries_r] provides both package [batteries]
	and all syntax extensions, in revised syntax. *)

    let cl_revised   = cl_use_batteries @ [A"-syntax";  A "camlp4r"] in
    flag ["ocaml"; "compile";  "use_batteries_r"] & S cl_revised;
    flag ["ocaml"; "ocamldep"; "use_batteries_r"] & S cl_revised;
    flag ["ocaml"; "doc";      "use_batteries_r"] & S cl_revised;
    flag ["ocaml"; "link";     "use_batteries_r"] & S cl_revised


(*    flag ["ocaml"; "compile";  "use_batteries"] & S[A "-verbose"; 
						    A"-package"; A "batteries.syntax.full"; 
						    A"-syntax";  A "batteries.syntax.full"];
    flag ["ocaml"; "ocamldep"; "use_batteries"] & S[A "-verbose";
						    A"-package"; A "batteries.syntax.full"; 
						    A"-syntax"; A "batteries.syntax.full"];
    flag ["ocaml"; "doc";      "use_batteries"] & S[A "-verbose";
						    A"-package"; A "batteries.syntax.full";
						    A"-syntax"; A "batteries.syntax.full"];
    flag ["ocaml"; "link";     "use_batteries"] & S[A "-verbose";
						    A"-package"; A "batteries.syntax.full";
						    A"-syntax"; A "batteries.syntax.full"];*)


end

let _ = dispatch begin function
   | Before_options ->
       OCamlFind.before_options ();
   | After_rules ->
       OCamlFind.after_rules ();
       Misc.after_rules ()

       
   | _ -> ()
end



(**
   which ocamlrun  ->   header

   print_backtrace -> ajouter "-b" après le header
**)
