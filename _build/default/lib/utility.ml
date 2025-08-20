open Pdf

(* fname_remove_extension: helper function to pull a filename from  *)
(* a full filename, returning "abc" from "../../abc.pdf". *)
let fname_remove_extension s = 
  let len = String.length s - 1 in
  match String.rindex_from_opt s len '.', 
        String.rindex_from_opt s len '/' with
  | Some dpos, Some spos when dpos > spos -> 
      String.sub s (spos + 1) (dpos - spos - 1)
  | Some dpos, None -> String.sub s 0 dpos
  | _ -> s 

(* rev_dict_entries: used to reverse the order of objects within a *)
(* Pdf.Dictionary list, essentially to preserve the integrity of the  *)
(* original file.  *)
let rev_dict_entries dict =
  let dlist = function 
    | Dictionary l -> l 
    | _ -> []
  in
  match dlist dict with
  | [] -> Dictionary []
  | ls -> Dictionary (List.rev ls);;

