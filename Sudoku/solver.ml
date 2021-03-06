type available = { loc : int * int; possible : int list }
(*s bo bil splošno uporabljen kot števec oziroma števka *)
(* TODO: tip stanja ustrezno popravite, saj boste med reševanjem zaradi učinkovitosti
   želeli imeti še kakšno dodatno informacijo *)
type state = { problem : Model.problem; current_grid : int option Model.grid; empty_cells : available array }

let print_state (state : state) : unit =
  Model.print_grid
    (function None -> "?" | Some digit -> string_of_int digit)
    state.current_grid

type response = Solved of Model.solution | Unsolved of state | Fail of state

let filter_integers (array : int option array) : int list =
  let rec filter_integers_aux acc list = function
    | [] -> acc
    | x :: xs -> match x with
      | None -> filter_integers_aux acc xs
      | Some s -> filter_integers_aux (s :: acc) xs
  in
  filter_integers_aux [] (Array.to_list array)

let init_possibilities row_ind col_ind (grid : int option grid) : int list =
  let row = filter_integers (Model.get_row grid row_ind)
  and column = filter_integers (Model.get_column grid col_ind) 
  and box_ind = Model.get_box_ind row_ind col_ind in
  let filtered_box_as_list = filter_integers Array.concat(Array.to_list(Model.get_box grid box_ind)) in
  (*škatlo moramo dati v obliko list, da jo lahko obravnavamo z isto funkcijo *)
  let rec filtered_box_as_list_aux acc s =
    if s < 10 then
      if (List.for_all (fun x -> x != s) row 
      && List.for_all (fun x -> x != s) column
      && List.for_all (fun x -> x != s) filtered_box_as_list)
        then filtered_box_as_list_aux (s :: acc) (s + 1)
      else 
        filtered_box_as_list_aux acc (s + 1)
    else
      acc
  in
  filtered_box_as_list_aux [] 1

let initialize_empty_cells (grid : int option Model.grid) : available array =
  let rec cells_aux acc i j : available list =
    if i < 9 then 
      let newj = if j = 8 then 0 else j + 1 in
      let newi = if newj = 0 then i + 1 else i in
      let newacc = 
        if grid.(i).(j) = None then 
          { loc = (i,j); possible = (init_possibilities i j grid) } :: acc 
        else 
          acc 
      in
      cells_aux newacc newi newj
    else 
      acc
  in
  Array.of_list (cells_aux [] 0 0)

let initialize_state (problem : Model.problem) : state =
{ 
  problem = problem;
  current_grid = Model.copy_grid problem.initial_grid;
  empty_cells = initialize_empty_cells problem.initial_grid;
}
let validate_state (state : state) : response =
  let unsolved =
    Array.exists (Array.exists Option.is_none) state.current_grid
  in
  if unsolved then Unsolved state
  else
    (* Option.get ne bo sprožil izjeme, ker so vse vrednosti v mreži oblike Some x *)
    let solution = Model.map_grid Option.get state.current_grid in
    if Model.is_valid_solution state.problem solution then Solved solution
    else Fail state

let update_empty_cells cells old_cell digit = 
  let rec update_empty_cells_aux acc = function
    | [] -> acc
    | x :: xs -> 
      let new_cell = 
        if x.loc = old_cell.loc then
          {
            loc = x.loc; 
            possible = List.filter (fun i -> i != digit) x.possible;
          }
        else 
          x
      in
      update_empty_cells_aux (new_cell :: acc) xs
  in
  Array.of_list (update_empty_cells_aux [] (Array.to_list cells))

(*v mrežo vstavi element in to mrežo zamenja s staro*)
let updated_grid (grid : 'a Model.grid) loc digit : 'a Model.grid = 
  let new_grid = Model.copy_grid grid in
  let (i, j) = loc in
  new_grid.(i).(j) <- (Some digit);
  new_grid

(* Vrne celico, ki ima več kot eno in hkrati najmanj možnosti od vseh. *)
let cell_with_least_possibilities state = 
  if Array.length state.empty_cells = 0 then
    None
  else  
    let rec find_aux cell len cells = match cells with
      | [] -> cell
      | x :: xs -> 
        let new_len = List.length x.possible in
        if new_len < len then 
          find_aux x new_len xs
        else
          find_aux cell len xs
    in
    let cell_arb = state.empty_cells.(0) in
    let len_arb = List.length cell_arb.possible in
    let cell = 
      find_aux cell_arb len_arb (Array.to_list state.empty_cells) 
    in
    if List.length cell.possible < 2 then
      None
    else
      Some cell
(*preteče vse digite in jih preveri *)
let rec different_digits = function
  | [] -> true
  | x::xs ->
    if List.exists (fun i -> i = x) xs then
      false
    else
      different_digits xs

let check_grid (grid : int option Model.grid) : bool =
  let rec valid_rows = function
    | [] -> true
    | row :: xs ->
      if different_digits (filter_integers row)
        then valid_rows xs
      else
        false
  in
  let rec boxes_aux acc = function
    | [] -> acc
    | box :: xs ->
      boxes_aux ((Array.concat (Array.to_list box)) :: acc) xs
  in
  let boolean = (
    valid_rows (boxes_aux [] (Model.boxes grid)) &&
    valid_rows (Model.rows grid) && 
    valid_rows (Model.columns grid) 
    
  )
  in
  boolean

let branch_state (state : state) : (state * state) option =
  (* TODO: Pripravite funkcijo, ki v trenutnem stanju poišče hipotezo, glede katere
     se je treba odločiti. Če ta obstaja, stanje razveji na dve stanji:
     v prvem predpostavi, da hipoteza velja, v drugem pa ravno obratno.
     Če bo vaš algoritem najprej poizkusil prvo možnost, vam morda pri drugi
     za začetek ni treba zapravljati preveč časa, saj ne bo nujno prišla v poštev. *)
  if check_grid state.current_grid then
    let empty_cell = cell_with_least_possibilities state in
    match empty_cell with
    | None -> None 
    | Some cell -> 
      let digit = List.hd cell.possible in
      let new_grid = updated_grid state.current_grid cell.loc digit in
      let a = {
        problem = state.problem;
        current_grid = new_grid;
        empty_cells = initialize_empty_cells new_grid;
      }
      and b = {
        problem = state.problem;
        current_grid = state.current_grid;
        empty_cells = update_empty_cells state.empty_cells cell digit;
      }
      in
      Some (a, b)
  else
    None

let clean_state state : state = 
  let rec clean_state_aux acc (cells : available list) : available list = 
    match cells with
    | [] -> acc
    | x :: xs -> 
      match x.possible with
      | [] -> clean_state_aux acc xs
      | digit :: [] -> 
        let (i, j) = x.loc in
        state.current_grid.(i).(j) <- (Some digit);
        clean_state_aux acc xs
      | e :: f :: _ -> clean_state_aux (x :: acc) xs
  in
  {
    problem = state.problem;
    current_grid = state.current_grid;
    empty_cells = Array.of_list (aux [] (Array.to_list state.empty_cells))
  }
(* pogledamo, če trenutno stanje pelje do rešitve *)
let rec solve_state (state : state) =
  (* uveljavimo trenutne omejitve in pogledamo, kam smo prišli *)
  (* TODO: na tej točki je stanje smiselno počistiti in zožiti možne rešitve *)
  match validate_state state with
  | Solved solution ->
      (* če smo našli rešitev, končamo *)
      Some solution
  | Fail fail ->
      (* prav tako končamo, če smo odkrili, da rešitev ni *)
      None
  | Unsolved state' ->
      (* če še nismo končali, raziščemo stanje, v katerem smo končali *)
      explore_state state'

and explore_state (state : state) =
  (* pri raziskovanju najprej pogledamo, ali lahko trenutno stanje razvejimo *)
  match branch_state state with
  | None ->
      (* če stanja ne moremo razvejiti, ga ne moremo raziskati *)
      None
  | Some (st1, st2) -> (
      (* če stanje lahko razvejimo na dve možnosti, poizkusimo prvo *)
      match solve_state st1 with
      | Some solution ->
          (* če prva možnost vodi do rešitve, do nje vodi tudi prvotno stanje *)
          Some solution
      | None ->
          (* če prva možnost ne vodi do rešitve, raziščemo še drugo možnost *)
          solve_state st2 )

let solve_problem (problem : Model.problem) =
  problem |> initialize_state |> solve_state
