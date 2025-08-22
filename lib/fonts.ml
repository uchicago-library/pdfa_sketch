open Pdf

(* let get_indirects (page : Pdfpage.t) =  *)
(*   let f acc pair = *)
(*     match snd pair with *)
(*     | Dictionary d -> (List.map snd d) @ acc *)
(*     | Indirect _ as i -> i :: acc *)
(*     | _ -> acc *)
(*   in *)
(*   List.fold_left f [] (get_fontobjs page.resources) *)
(**)
(* let fonts_of_page (pdf : Pdf.t) (page : Pdfpage.t) = *)
(*   List.map (fun obj -> direct pdf obj) (get_indirects page) *)

let rec is_embedded pdf fontobj : pdfobject option =
  let has key obj =
    Option.is_some (lookup_immediate key obj) 
  in
  match Pdf.lookup_direct pdf "/FontDescriptor" fontobj with
  | Some fd ->
      if (has "/FontFile" fd || has "/FontFile2" fd || has "/FontFile3" fd)
      then Some fd
      else None
  | None ->
      let search_indirect = function
        | (_, (Indirect n)) -> is_embedded pdf (lookup_obj pdf n)
        | _ -> None
      in
      match fontobj with
      | Dictionary objlist -> List.find_map search_indirect objlist
      | _ -> None
