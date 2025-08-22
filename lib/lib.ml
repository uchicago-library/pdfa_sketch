(* edit_xmp: First creates a valid xmp packet which uses functions *)
(* from the packet library of whom include all the logic, error checking *)
(* and control flow for handling the xmp, then we insert the object and *)
(* refer to it from the catalog object. *)
let edit_xmp (pdf:Pdf.t) : unit =
  let packet =
    Packet.modify_pdfaid pdf |> 
    Packet.modify_creator pdf |> 
    Packet.modify_producer pdf |> 
    Packet.modify_darwin pdf 
  in
  let catalog = 
    Pdf.add_dict_entry 
      (Pdf.remove_dict_entry (Pdf.catalog_of_pdf pdf) "/Metadata") 
      "/Metadata" (Indirect (Packet.xmp_insertion pdf packet))
      |> Utility.rev_dict_entries 
  in
  Pdf.addobj_given_num pdf (pdf.Pdf.root, catalog)

(* edit_output_intent: embeds a .icc colorspace file  *)
(* from Adobe into a new "/OutputIntents" object, then adds an  *)
(* entry in the catalog object (pdf.root) referencing the new object. *)
let edit_output_intent (pdf:Pdf.t) (icc_fname:string) =
  let icc_objnum = 
    Pdf.addobj pdf (Outintent.create_icc_stream icc_fname) 
  in
  let oi = 
    Outintent.make_oi 
      "/GTS_PDFA1" 
      (Utility.fname_remove_extension icc_fname) 
      icc_objnum 
  in
  let catalog = 
    Pdf.add_dict_entry 
      (Pdf.remove_dict_entry (Pdf.catalog_of_pdf pdf) "/OutputIntents")
      "/OutputIntents" (Pdf.Array [Pdf.Indirect (Pdf.addobj pdf oi)]) 
      |> Utility.rev_dict_entries 
  in 
  Pdf.addobj_given_num pdf (pdf.Pdf.root, catalog)

(* pdfa_convert: Basic control flow using highest level functions to  *)
(* read in a pdf through a file, edit both the xmp and outputintents,  *)
(* and export it to a converted pdfa file. *)
let pdfa_convert (pdf_fname:string) (icc_fname:string) =
  let pdf =
    Pdfread.pdf_of_file None None pdf_fname 
  in
  edit_xmp pdf;
  edit_output_intent pdf icc_fname;
  Pdfwrite.pdf_to_file pdf 
    ((Utility.fname_remove_extension pdf_fname) ^ "_pdfa.pdf")

module Fonts = Fonts
module Outintent = Outintent
module Packet = Packet
module Utility = Utility
