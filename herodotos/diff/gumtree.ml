
exception Unexpected of string

let diffcmd = "gumtree --output asrc "

let parse_diff v prefix file =
  let ver_file = Misc.strip_prefix prefix file in
  if Sys.file_exists file then
    begin
      LOG "Parsing Gumtree diff: %s" file LEVEL TRACE;
      let x = open_in_bin file in
      try
	let tree = input_value x in
	close_in x;
	[(ver_file, Ast_diff.Gumtree (tree))]
      with
	  Misc.Strip msg ->
	    LOG "Strip: %s" msg LEVEL ERROR;
	    close_in x;
	    raise (Unexpected msg)
	| e ->
	  Printexc.print_backtrace stderr;
	  let newfile = file ^ Global.failed in
	  LOG "Failed while parsing: check %s" newfile LEVEL ERROR;
	  Sys.rename file newfile;
	  []
    end
  else
    [(ver_file, Ast_diff.DeletedFile)]

let get_pos_before tree =
  let Ast_diff.Tree(pos_before, _, _) = tree in
  pos_before

let get_pos_after tree =
  let Ast_diff.Tree(_, pos_after, _) = tree in
  pos_after

let get_children tree =
  let Ast_diff.Tree(_, _, children) = tree in
  children

(* Pretty-printing *)
let show_gumtree_pos (_, _, bl, bc, el, ec) =
  Printf.sprintf "%d:%d-%d:%d" bl bc el ec

let rec show_gumtree dorec depth tree =
  let before = get_pos_before tree in
  let oafter = get_pos_after tree in
  let children = get_children tree in
  LOG "%s- %s -> %s"
    (String.make depth ' ')
    (show_gumtree_pos before)
    (match oafter with
	Some after -> show_gumtree_pos after
      | None -> "XXX"
    )
    LEVEL TRACE;
  if dorec then
    List.iter (show_gumtree dorec (depth +1)) children

(* *)
let is_perfect pos (tree:Ast_diff.tree) =
  let (line, colb, cole) = pos in
  let (_, _, bl, bc, el, ec)  = get_pos_before tree in
  line = bl && line = el
       && colb = bc && cole = ec

let found tree =
  show_gumtree false 0 tree;
  LOG "-----------------" LEVEL TRACE;
  true
 
let match_tree pos (tree:Ast_diff.tree) =
  let (line, colb, cole) = pos in
  let (_, _, bl, bc, el, ec)  = get_pos_before tree in
  if line > bl && (line < el || line = el && cole <= ec) then
    (* Match a node that start before, but may end at the right line, or after *)
    (if !Misc.debug then LOG "match_tree: case 1" LEVEL TRACE;
     found tree)
  else if line = bl && line < el
       && colb >= bc then
    (* Match a *large* node that start at the right line. The begin column must be right too. *)
    (if !Misc.debug then LOG "match_tree: case 2" LEVEL TRACE;
     found tree)
  else if line = bl && line = el
	       && colb >= bc && cole <= ec then
    (* The perfect line matching is not capture in the previous case.
       We check it here, and also check the columns.
    *)
    (if !Misc.debug then LOG "match_tree: case 3" LEVEL TRACE;
     found tree)
  else
    (if !Misc.debug then LOG "match_tree: case 4" LEVEL TRACE;
     false)

let rec lookup_tree ver file pos (tree:Ast_diff.tree) : Ast_diff.tree =
  Debug.profile_code_silent "Gumtree.lookup_tree"
    (fun () ->
      let children = get_children tree in
      try
	let candidate = List.find (match_tree pos) children in
	if is_perfect pos candidate then
	  (LOG "lookup_tree: perfect" LEVEL TRACE;
	   candidate)
	else
	  (LOG "lookup_tree: !perfect - recurse" LEVEL TRACE;
	   lookup_tree ver file pos candidate)
      with Not_found ->
	LOG "lookup_tree: Not_found - Return current element (%s/%s)" ver file LEVEL FATAL;
	tree
    )

let compute_new_pos_with_gumtree (diffs: Ast_diff.diffs) file ver pos : bool * (Ast_diff.lineprediction * int * int) =
  Debug.profile_code_silent "Gumtree.compute_new_pos_with_gumtree"
    (fun () ->
      let (line, colb, cole) = pos in
      try
	match List.assoc (ver, file) diffs with
	    Ast_diff.Gumtree root ->
	      begin
		let matched_tree = lookup_tree ver file pos root in
		show_gumtree true 0 matched_tree;
		LOG "-----------------" LEVEL TRACE;
		match get_pos_after matched_tree with
		    Some (_, _, bl, bc, el, ec) ->
		      if bl == el then
			(true, (Ast_diff.Sing bl, bc, ec))
		      else
			(true, (Ast_diff.Cpl (bl, el), bc, ec))
		  | None -> (true, (Ast_diff.Deleted false, 0, 0))
	      end
	  | Ast_diff.DeletedFile -> (true, (Ast_diff.Unlink, 0, 0))
	  | _ -> raise (Unexpected "Wrong diff type")
      with Not_found ->
	let msg = "No gumtree diff for "^ file ^ " in vers. " ^ ver in
	LOG msg LEVEL FATAL;
	raise (Unexpected msg)
    )
