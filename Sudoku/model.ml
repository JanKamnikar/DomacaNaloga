(* Pomožni tip, ki predstavlja mrežo *)

type 'a grid = 'a Array.t Array.t

(* Funkcije za prikaz mreže.
   Te definiramo najprej, da si lahko z njimi pomagamo pri iskanju napak. *)

(* Razbije seznam [lst] v seznam seznamov dolžine [size] *)
let chunkify size lst =
  let rec aux chunk chunks n lst =
    match (n, lst) with
    | _, [] when chunk = [] -> List.rev chunks
    | _, [] -> List.rev (List.rev chunk :: chunks)
    | 0, _ :: _ -> aux [] (List.rev chunk :: chunks) size lst
    | _, x :: xs -> aux (x :: chunk) chunks (n - 1) xs
  in
  aux [] [] size lst

let string_of_list string_of_element sep lst =
  lst |> List.map string_of_element |> String.concat sep

let string_of_nested_list string_of_element inner_sep outer_sep =
  string_of_list (string_of_list string_of_element inner_sep) outer_sep

let string_of_row string_of_cell row =
  let string_of_cells =
    row |> Array.to_list |> chunkify 3
    |> string_of_nested_list string_of_cell "" "│"
  in
  "┃" ^ string_of_cells ^ "┃\n"

let print_grid string_of_cell grid =
  let ln = "───" in
  let big = "━━━" in
  let divider = "┠" ^ ln ^ "┼" ^ ln ^ "┼" ^ ln ^ "┨\n" in
  let row_blocks =
    grid |> Array.to_list |> chunkify 3
    |> string_of_nested_list (string_of_row string_of_cell) "" divider
  in
  Printf.printf "┏%s┯%s┯%s┓\n" big big big;
  Printf.printf "%s" row_blocks;
  Printf.printf "┗%s┷%s┷%s┛\n" big big big

(* Funkcije za dostopanje do elementov mreže *)

let get_row (grid : 'a grid) (row_ind : int) = 
 Array.init 9 (fun col_ind -> grid.(row_ind).(col_ind))

let rows grid = List.init 9 (get_row grid)

let get_column (grid : 'a grid) (col_ind : int) =
  Array.init 9 (fun row_ind -> grid.(row_ind).(col_ind))

let columns grid = List.init 9 (get_column grid)

let get_box (grid : 'a grid) (box_ind : int) = 
  let row = (box_ind / 3) * 3 in
  let col = (box_ind mod 3) * 3 in
  let box = Array.init 3 
  (
    fun i -> Array.init 3 
    (
      fun j -> grid.(row + i).(col + j)
    )
  )
  in
  box
(*dodatno definiram še "pomožno funkcijo" za lažje dostopanje do škatle*)
let get_box_ind row_ind col_ind =
(row_ind / 3) * 3 + (col_ind / 3)


let boxes grid : 'a grid list = List.init 9 (get_box grid)

(* Funkcije za ustvarjanje novih mrež *)

let map_grid (f : 'a -> 'b) (grid : 'a grid) : 'b grid = 
  Array.init 9 (fun i -> Array.map f grid.(i))

let copy_grid (grid : 'a grid) : 'a grid = map_grid (fun x -> x) grid

let foldi_grid (f : int -> int -> 'a -> 'acc -> 'acc) (grid : 'a grid)
    (acc : 'acc) : 'acc =
  let acc, _ =
    Array.fold_left
      (fun (acc, row_ind) row ->
        let acc, _ =
          Array.fold_left
            (fun (acc, col_ind) cell ->
              (f row_ind col_ind cell acc, col_ind + 1))
            (acc, 0) row
        in
        (acc, row_ind + 1))
      (acc, 0) grid
  in
  acc

let row_of_string cell_of_char str =
  List.init (String.length str) (String.get str) |> List.filter_map cell_of_char

let grid_of_string cell_of_char str =
  let grid =
    str |> String.split_on_char '\n'
    |> List.map (row_of_string cell_of_char)
    |> List.filter (function [] -> false | _ -> true)
    |> List.map Array.of_list |> Array.of_list
  in
  if Array.length grid <> 9 then failwith "Nepravilno število vrstic";
  if Array.exists (fun x -> x <> 9) (Array.map Array.length grid) then
    failwith "Nepravilno število stolpcev";
  grid

(* Model za vhodne probleme *)

type problem = { initial_grid : int option grid }

let string_Cell (cell : int option) = function
  | None -> " "
  | Some n -> string_of_int n

let print_problem problem : unit = print_grid string_Cell problem.initial_grid


let problem_of_string str =
  let cell_of_char = function
    | ' ' -> Some None
    | c when '1' <= c && c <= '9' -> Some (Some (Char.code c - Char.code '0'))
    | _ -> None
  in
  { initial_grid = grid_of_string cell_of_char str }

(* Model za izhodne rešitve *)

type solution = int grid

let print_solution solution = print_grid string_of_int solution


let rec valid_row (row : int array) : bool = 
  let length = Array.length row in
  if length < 2 
    then true
  else
    let first = row.(0)
    and rest = Array.init (len - 1) (fun x -> row.(x + 1)) in
    if Array.exists (fun x -> x = first) rest then false 
    else valid_row rest
(* valid_row deluje enako za stolpce in vrstice ker sta istega tipa *)

let valid_box (box : int array array) : bool =
  valid_row (Array.concat (Array.to_list box))



let valid_grid (grid : solution) : bool = 
  List.for_all valid_row (rows grid) && 
  List.for_all valid_row (columns grid) && 
  List.for_all valid_box (boxes grid)
(* preveri če izpolnjen sudoku deluje po pravilih *)

let compare_cells (c : int option) (d : int) : bool =
  match c with
  | None -> true
  | Some x -> x = d

let is_applicable_solution (problem : problem) (solution : solution) : bool = 
  let values = Array.init 9 
  (
    fun i -> Array.init 9 
    (
      fun j -> compare_cells problem.initial_grid.(i).(j) solution.(i).(j)
    )
  )
  in
  Array.for_all (fun array -> Array.for_all (fun y -> y = true) array) values

let is_valid_solution (problem : problem) (solution : solution) = 
  valid_grid solution && is_applicable_solution problem solution 