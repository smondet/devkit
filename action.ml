(** Misc *)

open ExtLib
open Printf

open Prelude

let period n f = 
  let count = ref 0 in
  (fun () -> incr count; if !count mod n = 0 then f !count)

let strl f l = sprintf "[%s]" (String.concat ";" (List.map f l))

let uniq p e =
  let h = Hashtbl.create 16 in
  Enum.filter (fun x ->
    let k = p x in
    if Hashtbl.mem h k then false else (Hashtbl.add h k (); true)) e

let list_uniq p = List.of_enum $ uniq p $ List.enum

let list_random_exn l = List.nth l (Random.int (List.length l))

let list_random = function
  | [] -> None
  | l -> list_random_exn l >> some

(** [partition l n] splits [l] into [n] chunks *)
let partition l n =
  let a = Array.make n [] in
  ExtList.List.iteri (fun i x -> let i = i mod n in a.(i) <- x :: a.(i)) l;
  a

(* FIXME *)

let bytes_string_f f = (* oh ugly *)
  if f < 1024. then sprintf "%uB" (int_of_float f) else
  if f < 1024. *. 1024. then sprintf "%uKB" (int_of_float (f /. 1024.)) else
  if f < 1024. *. 1024. *. 1024. then sprintf "%.1fMB" (f /. 1024. /. 1024.) else
  sprintf "%.1fGB" (f /. 1024. /. 1024. /. 1024.)

let bytes_string = bytes_string_f $ float_of_int

let caml_words_f f =
  bytes_string_f (f *. (float_of_int (Sys.word_size / 8)))

let caml_words = caml_words_f $ float_of_int

(* EMXIF *)

module App(Info : sig val version : string val name : string end) = struct

let run main =
  Printexc.record_backtrace true;
  Log.self #info "%s started. Version %s. PID %u" Info.name Info.version (Unix.getpid ());
  try
    main ();
    Log.self #info "%s finished." Info.name
  with
    e -> Log.self #error "%s aborted : %s" Info.name (Exn.str e); Log.self #error "%s" (Printexc.get_backtrace ())

end

class timer = 
let tm = Unix.gettimeofday  in
object

val start = tm ()
method get = tm () -. start
method gets = sprintf "%.6f" & tm () -. start
method get_str = Time.duration_str & tm () -. start

end

let log ?name f x =
  try
    Option.may (Log.self #info "Action \"%s\" started") name;
    let t = Unix.gettimeofday () in
    let () = f x in
    Option.may (fun name -> Log.self #info "Action \"%s\" finished (%f secs)" name (Unix.gettimeofday () -. t)) name
  with
    e ->
      let name = Option.map_default (Printf.sprintf " \"%s\"") "" name in
      Log.self #error "Action%s aborted with uncaught exception : %s" name (Exn.str e);
      Log.self #error "%s" (Printexc.get_backtrace ())

let log_thread ?name f x =
  Thread.create (fun () -> log ?name f x) ()
