open Pdf

(* make_oi: Creates the "/OutputIntents" pdfobject *)
let make_oi s condition_id output_profile_num =
  Dictionary
  [
    "/S", Name s;
    "/Type", Name "/OutputIntent";
    "/OutputConditionIdentifier", String condition_id;
    "/DestOutputProfile", Indirect output_profile_num
  ]

(* bytes_of_file: helper function which returns the bytes of a file *)
let bytes_of_file fname =
  let channel = open_in_bin fname in
  let bytes = Pdfio.bytes_of_input_channel channel in
  close_in channel; 
  bytes

(* dictstream_of_file: Creates a valid dictionary stream from an *)
(* existing Dictionary object and a .icc file. *)
let dictstream_of_file fname dict = 
  let bytes = bytes_of_file fname in
  let len = Pdfio.bytes_size bytes in
  let ldict = add_dict_entry dict "/Length" (Integer len) in
  Stream (ref (ldict, Got bytes))

(* create_icc_stream: Creates the full stream object from a file. *)
let create_icc_stream icc_fname =
  let icc_dict = Dictionary ["/N", Integer 3] in
  dictstream_of_file icc_fname icc_dict
