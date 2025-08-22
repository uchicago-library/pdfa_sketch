open Printf

let chop_ext_safe (f : string) =
  try Filename.chop_extension f with Invalid_argument _ -> f

let first_existing (paths : string list) : string option =
  let rec go = function
    | [] -> None
    | p :: ps -> if Sys.file_exists p then Some p else go ps
  in
  go paths

let resolve_default_icc (override : string option) : string =
  match override with
  | Some p when Sys.file_exists p -> p
  | Some p ->
      eprintf "Error: ICC profile not found: %s\n%!" p; exit 2
  | None ->
      let candidates =
        (match Sys.getenv_opt "PDF_ICC_PATH" with Some v -> [v] | None -> []) @ [
          "/Library/ColorSync/Profiles/AdobeRGB1998.icc";            
          "/System/Library/ColorSync/Profiles/AdobeRGB1998.icc";     
          "/usr/share/color/icc/AdobeRGB1998.icc";                    
          "/usr/share/color/icc/adobe/AdobeRGB1998.icc";
          "/usr/share/color/icc/colord/AdobeRGB1998.icc";
          "/usr/local/share/color/icc/AdobeRGB1998.icc";
        ]
      in
      match first_existing candidates with
      | Some p -> p
      | None ->
          eprintf "Error: Couldn't locate a default AdobeRGB (1998) ICC profile.\n\
                   Set PDF_ICC_PATH or pass --icc PATH.\n%!";
          exit 2

let pdfa_convert_to_out ~(icc : string) ~(out_path : string) (pdf_path : string) =
  let pdf = Pdfread.pdf_of_file None None pdf_path in
  Lib.edit_xmp pdf;
  Lib.edit_output_intent pdf icc;
  Pdfwrite.pdf_to_file pdf out_path

let () =
  let icc_arg  = ref None in
  let out_arg  = ref None in
  let inputs   = ref [] in

  let speclist = [
    ("--icc", Arg.String (fun s -> icc_arg := Some s),
      "Path to AdobeRGB 1998 ICC profile (optional - $PDF_ICC_PATH or best guess)");
    ("-o", Arg.String (fun s -> out_arg := Some s),
      "Output filename (written to current directory if relative)");
  ] in

  let usage = "Usage: pdfa-convert <input.pdf> [--icc PROFILE.icc] [-o out.pdf]" in
  Arg.parse speclist (fun s -> inputs := s :: !inputs) usage;

  match List.rev !inputs with
  | [pdf_path] ->
      if not (Sys.file_exists pdf_path) then (
        eprintf "Error: Input PDF not found: %s\n%!" pdf_path; exit 2
      );
      let icc_path = resolve_default_icc !icc_arg in
      let cwd      = Sys.getcwd () in
      let base     = Filename.basename pdf_path in
      let stem     = chop_ext_safe base in
      let out_path =
        match !out_arg with
        | Some o when Filename.is_relative o -> Filename.concat cwd o
        | Some o -> o
        | None -> Filename.concat cwd (stem ^ "_pdfa.pdf")
      in
      pdfa_convert_to_out ~icc:icc_path ~out_path pdf_path;
      printf "Wrote %s\n%!" out_path
  | _ ->
      Arg.usage speclist usage; exit 1
