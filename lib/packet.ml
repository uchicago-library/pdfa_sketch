open Pdf
open Ezxmlm

let ns_xmlns = "http://www.w3.org/2000/xmlns/"
let ns_pdfaid = "http://www.aiim.org/pdfa/ns/id/"
let ns_x = "adobe:ns:meta/"
let ns_rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
let ns_xmp = "http://ns.adobe.com/xap/1.0/"
let ns_pdf = "http://ns.adobe.com/pdf/1.3/"
let ns_dc = "http://purl.org/dc/elements/1.1/"
let ns_xml = "http://www.w3.org/XML/1998/namespace"

let xmp_of_pdf (pdf:Pdf.t) : nodes option =
  match indirect_number pdf "/Metadata" 
        (catalog_of_pdf pdf) with
  | None -> None
  | Some objnum ->
    begin match lookup_obj pdf objnum with
    | Stream r ->
        let (_, contents_ref) = !r in
        begin match contents_ref with
        | Got bytes ->
            let s = Pdfio.string_of_bytes bytes in
            (try
               let (_, nodes) = Ezxmlm.from_string s in
               Some nodes
             with _ -> None)
        | _ ->
            None
        end
    | _ ->
        None
    end

let rec replace_tag_val t data (nodes:nodes) : nodes =
  let f = function
    | `Data s -> `Data s 
    | `El (((ns, tag), attrs), _) when tag = t->
        `El (((ns, tag), attrs), [`Data data])
    | `El (name, children) ->
        `El (name, replace_tag_val t data children)
  in
  List.map f nodes

let find_pdfaid (nodes : nodes) : (string * string) option =
  try
    let descs =
      member "xmpmeta" nodes |> 
      member "RDF" |> 
      members_with_attr "Description"
    in
    let get_pdfaid (attrs, _children) =
      let part_opt = List.assoc_opt (ns_pdfaid, "part") attrs
      and conf_opt = List.assoc_opt (ns_pdfaid, "conformance") attrs in
      match part_opt, conf_opt with
      | Some p, Some c -> Some (p, c)
      | _ -> None
    in
    List.find_map get_pdfaid descs
  with
    Tag_not_found _ -> None;;

let make_xmp_packet () : nodes =
  let el ?(ns="") ?(attrs=[]) name children : node =
    `El (((ns, name), attrs), children)
  in
  let rdf =
    el ~ns:ns_rdf ~attrs:[ ((ns_xmlns, "rdf"), ns_rdf) ] "RDF" []
  in
  let xmpmeta =
    el ~ns:ns_x ~attrs:[ ((ns_xmlns, "x"), ns_x) ] "xmpmeta" [rdf]
  in
  [xmpmeta]

let insert_desc dattr dchild (nodes:nodes) : nodes =
  let rec aux = function
    | `El (((ns, "RDF"), a), c) ->
        `El (((ns, "RDF"), a), c @ 
        [`El (((ns, "Description"), dattr), dchild)])
    | `El (t, c) -> `El (t, List.map aux c)
    | `Data _ as d -> d
  in
  List.map aux nodes

let remove_pdfaid_desc (nodes:Ezxmlm.nodes) : Ezxmlm.nodes =
  let rec aux = function
    | `El (((ns, "Description"), attrs), children) ->
        let has_pdfaid =
          List.exists (fun ((attr_ns, _), _) -> attr_ns = ns_pdfaid) attrs
        in
        if has_pdfaid then
          None 
        else
          Some (`El (((ns, "Description"), attrs), 
          List.filter_map aux children))
    | `El (tag, children) ->
        Some (`El (tag, List.filter_map aux children))
    | (`Data _ as d) -> Some d
  in
  List.filter_map aux nodes

let get_info (pdf:Pdf.t) (key:string) =
  let v_opt =
    match lookup_direct pdf "/Info" pdf.trailerdict with
    | Some (Dictionary dlist) ->
      List.find_opt (fun (n, _) -> n = key) dlist
    | _ -> None 
  in
  match v_opt with
  | Some (_, obj) ->
      (match obj with
      | String s -> Some s
      | Name n -> Some n
      | _ -> None)
  | _ -> None 

(* Search and replace, returning option nodes *)
let search_replace_tag t data (nodes:nodes) =
  let tag_exists = function
    | `El (((_, tag), _), _) when tag = t ->
        true
    | _ -> false
  in
  if List.exists tag_exists nodes then 
    let f = function
      | `Data s -> `Data s 
      | `El (((ns, tag), attrs), _) when tag = t->
          `El (((ns, tag), attrs), [`Data data])
      | `El (name, children) ->
          `El (name, replace_tag_val t data children)
    in
    Some (List.map f nodes)
  else
    None

let insert_producer_tag (pdf:Pdf.t) nodes =
  let desc_tag =
    [((ns_rdf, "about"), "");
     ((ns_xmlns, "pdf"), ns_pdf)]
  in
  let producer_tag = 
    match get_info pdf "/Producer" with
    | Some s -> `El (((ns_pdf, "Producer"), []), [`Data s])
    | _ -> `El (((ns_pdf, "Producer"), []), [])
  in
  insert_desc desc_tag [producer_tag] nodes

let insert_xmp_tags (pdf:Pdf.t) nodes =
  let desc_tag = 
    [((ns_rdf, "about"), "");
     ((ns_xmlns, "xmp"), ns_xmp)]
  in
  let creator_tool = 
    match get_info pdf "/Creator" with
    | Some s -> `El (((ns_xmp, "CreatorTool"), []), [`Data s])
    | _ -> `El (((ns_xmp, "CreatorTool"), []), [])
  in
  insert_desc desc_tag [creator_tool] nodes

let insert_pdfaid_tag nodes : nodes =
  insert_desc 
    [((ns_rdf, "about"), "");
     ((ns_xmlns, "pdfaid"), ns_pdfaid);
     ((ns_pdfaid, "part"), "1");
     ((ns_pdfaid, "conformance"), "B")] [] nodes

let xpacket_wrap ?(id="W5M0MpCehiHzreSzNTczkc9d") (xml:string) : string =
  let prefix = "<?xpacket" in 
  let plen = String.length prefix in
  let has_xpacket xmp = 
    let index = String.index_from_opt xmp 0 '<' in
    match index with
    | Some i -> 
        (match String.sub xmp i plen with
        | str when str = prefix -> true
        | _ -> false)
    | None -> false
  in
  if has_xpacket xml then xml else 
    let header = Printf.sprintf "<?xpacket begin=\"\" id=\"%s\"?>" id in
    let footer = Printf.sprintf "<?xpacket end=\"%c\"?>" 'w' in
    header ^ "\n" ^ xml ^ "\n" ^ footer

let xpacket_wrap_nodes ?id (nodes:nodes) : string =
  let body = Ezxmlm.to_string ~decl:false nodes in
  xpacket_wrap ?id body

let xmp_insertion (pdf:Pdf.t) (nodes:nodes) : int =
  let bytes = xpacket_wrap_nodes nodes |> Pdfio.bytes_of_string in
  let len = Pdfio.bytes_size bytes in
  let xmp_dict = Dictionary ["/Type", Name "/Metadata"; "/Subtype", Name "/XML"] in
  let ldict = add_dict_entry xmp_dict "/Length" (Integer len) in
  addobj pdf (Stream (ref (ldict, Got bytes)))

let modify_pdfaid (pdf:Pdf.t) =
  match xmp_of_pdf pdf with
  | None -> make_xmp_packet () |> insert_pdfaid_tag 
  | Some n -> 
    match find_pdfaid n with
    | None -> insert_pdfaid_tag n
    | Some (p, c) when p = "1" && c = "B" -> n
    | _ -> remove_pdfaid_desc n |> insert_pdfaid_tag

let modify_creator pdf nodes : nodes = 
  match get_info pdf "/Creator" with
  | Some s -> 
     (match search_replace_tag "CreatorTool" s nodes with
      | Some n -> n
      | None -> insert_xmp_tags pdf nodes)
  | _ -> nodes

let modify_producer pdf nodes : nodes =
  match get_info pdf "/Producer" with
  | Some s ->
      (match search_replace_tag "Producer" s nodes with
      | Some n -> n
      | None -> insert_producer_tag pdf nodes)
  | _ -> nodes


(* let insert_xmp_tags (pdf:Pdf.t) nodes = *)
(*   let desc_tag =  *)
(*     [((ns_rdf, "about"), ""); *)
(*      ((ns_xmlns, "xmp"), ns_xmp)] *)
(*   in *)
(*   let creator_tool =  *)
(*     match get_info pdf "/Creator" with *)
(*     | Some s -> `El (((ns_xmp, "CreatorTool"), []), [`Data s]) *)
(*     | _ -> `El (((ns_xmp, "CreatorTool"), []), []) *)
(*   in *)
(*   insert_desc desc_tag [creator_tool] nodes *)
(**)
(* <rdf:Description rdf:about="" xmlns:dc='http://purl.org/dc/elements/1.1/' dc:format='application/pdf'> *)
(*   <dc:title> *)
(*     <rdf:Alt> <rdf:li xml:lang='x-default'> </rdf:li> </rdf:Alt> *)
(*   </dc:title> *)
(*   <dc:creator> *)
(*     <rdf:Seq> <rdf:li> </rdf:li> </rdf:Seq> *)
(*   </dc:creator> *)
(*   <dc:description> *)
(*     <rdf:Alt> <rdf:li xml:lang='x-default'> </rdf:li> </rdf:Alt> *)
(*   </dc:description> *)
(* </rdf:Description> *)

let insert_darwin_tags (pdf:Pdf.t) nodes = 
  let f = function | Some v -> v | None -> [] in
  let desc_tag = 
    [((ns_rdf, "about"), "");
     ((ns_xmlns, "dc"), ns_dc);
     ((ns_dc, "format"), "application/pdf")]
  in
  let rdf_alt child = [`El (((ns_rdf, "Alt"), []), (f child))] in
  let rdf_seq child = [`El (((ns_rdf, "Seq"), []), (f child))] in
  let rdf_li attr data = 
    match data with
    | Some d -> Some [`El (((ns_rdf, "li"), (f attr)), [`Data d])]
    | None -> Some [`El (((ns_rdf, "li"), (f attr)), [])]
  in
  let title = 
    `El (((ns_dc, "title"), []), 
      (rdf_alt (rdf_li (Some [((ns_xml, "lang"), "x-default")]) (get_info pdf "/Title"))))
  in
  let creator = 
    let ct = (rdf_seq (rdf_li None (get_info pdf "/Author"))) in
    `El (((ns_dc, "creator"), []), ct)
  in
  let description = 
    let dt = (rdf_alt (rdf_li (Some [((ns_xml, "lang"), "x-default")]) (get_info pdf "/Subject"))) in
    `El (((ns_dc, "description"), []), dt)
  in
  insert_desc desc_tag [title; creator; description] nodes

let modify_darwin pdf nodes : nodes =
  let f s = Option.is_some (get_info pdf s) in
  if f "/Author" || f "/Title" || f "/Subject" 
  then insert_darwin_tags pdf nodes
  else nodes

(* |  ISO 19005-1:2005 *)
(* |  The value of Keywords entry from the document information dictionary, if present, and its analogous XMP property "pdf:Keywords" shall be equivalent *)
(* |  The value of Keywords entry from the document Info dictionary and its matching XMP property "pdf:Keywords" are not equivalent (Info /Keywords = "", XMP pdf:Keywords = null) *)


let insert_producer_keywords_tag (pdf:Pdf.t) nodes =
  let desc_tag =
    [((ns_rdf, "about"), "");
     ((ns_xmlns, "pdf"), ns_pdf)]
  in
  let producer_tag = 
    match get_info pdf "/Producer" with
    | Some s -> `El (((ns_pdf, "Producer"), []), [`Data s])
    | _ -> `El (((ns_pdf, "Producer"), []), [])
  in
  let keywords_tag = 
    match get_info pdf "/Keywords" with
    | Some s -> `El (((ns_pdf, "Keywords"), []), [`Data s])
    | _ -> `El (((ns_pdf, "Keywords"), []), [])
  in
  insert_desc desc_tag [producer_tag; keywords_tag] nodes
  
let modify_producer_keywords pdf nodes : nodes =
  match get_info pdf "/Producer" with
  | Some s ->
      (match search_replace_tag "Producer" s nodes with
      | Some n -> n
      | None -> insert_producer_tag pdf nodes)
  | _ -> nodes





  
    




