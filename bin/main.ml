open GroupProject.Point
open GroupProject.Csvreader
open GroupProject.Kmeans
open GroupProject.Knn
open GMain
open Gtk

(* -------------------------------------------------------------------------- *)
(* HELPER FUNCTIONS *)
(* -------------------------------------------------------------------------- *)

(** [generate] generates a file with random points *)
let generate () =
  Random.self_init ();
  let random_a_b a b = a + Random.int b in
  let dim = random_a_b 1 3 in
  let n = random_a_b 1 100 in
  let points_lst = ref [] in
  for i = 0 to n - 1 do
    let line = ref "" in
    for j = 0 to dim - 1 do
      let coordinate = random_a_b 1 100 in
      let coordinate_str = string_of_float (float_of_int coordinate /. 10.) in
      if !line == "" then line := coordinate_str
      else line := !line ^ ", " ^ coordinate_str
    done;
    points_lst := !line :: !points_lst
  done;
  BatFile.write_lines "data/random.csv" (BatList.enum !points_lst)

(* -------------------------------------------------------------------------- *)
(* WIDGET UTILITIES *)
(* -------------------------------------------------------------------------- *)

(** [find_widget_by_name] locates a widget according to the name *)
let find_widget_by_name parent name widget_type =
  let rec find_in_container container =
    let children = container#children in
    List.find_opt
      (fun child ->
        try
          match child#misc#get with
          | Some w -> w#name = name
          | None -> false
        with _ -> false)
      children
  in
  match find_in_container parent with
  | Some w -> Some (widget_type w)
  | None -> None

(* -------------------------------------------------------------------------- *)
(* VISUALIZATIONS *)
(* -------------------------------------------------------------------------- *)

type color_array = (string * (float * float * float)) array
(** [color_array] describes the definition of a color array *)

(** [create_1d_graph] outputs a file with a graph in 1D. *)
let create_1d_graph filename points clusters colors distance_metric =
  let max_x = ref (-.max_float) in
  let min_x = ref max_float in

  let x = Array.make (List.length points) 0.0 in

  for i = 0 to List.length points - 1 do
    let coords = GroupProject.Point.get_coordinates (List.nth points i) in
    let curr_x = List.nth coords 0 in
    x.(i) <- curr_x;
    min_x := min !min_x curr_x;
    max_x := max !max_x curr_x
  done;

  let x_clusters = Array.make (List.length clusters) 0.0 in
  for i = 0 to List.length clusters - 1 do
    let coords = GroupProject.Point.get_coordinates (List.nth clusters i) in
    x_clusters.(i) <- List.nth coords 0
  done;

  let open Plplot in
  plsdev "png";
  plsfnam filename;
  plinit ();

  Array.iteri
    (fun i (_, (r, g, b)) ->
      plscol0 (i + 1)
        (int_of_float (r *. 255.))
        (int_of_float (g *. 255.))
        (int_of_float (b *. 255.)))
    colors;

  plscol0 (Array.length colors + 1) 255 255 255;
  plcol0 (Array.length colors + 1);

  let range = !max_x -. !min_x in
  plenv (!min_x -. (0.1 *. range)) (!max_x +. (0.1 *. range)) (-0.1) 0.1 0 0;
  pllab "X-axis" "" "1D Graph";

  List.iteri
    (fun i cluster_point ->
      let color_index = (i mod Array.length colors) + 1 in
      plcol0 color_index;

      let cluster_points =
        List.filter
          (fun p ->
            let curr_dist = distance_metric p cluster_point in
            List.for_all
              (fun other_cluster ->
                curr_dist <= distance_metric p other_cluster)
              clusters)
          points
      in

      let x_cluster_points =
        Array.of_list
          (List.map
             (fun p -> List.nth (GroupProject.Point.get_coordinates p) 0)
             cluster_points)
      in

      let y_fixed = Array.make (Array.length x_cluster_points) 0.0 in
      plpoin x_cluster_points y_fixed 9;

      let center_coords = GroupProject.Point.get_coordinates cluster_point in
      let cx = List.nth center_coords 0 in
      plcol0 (Array.length colors + 1);
      plpoin [| cx |] [| 0.0 |] 5)
    clusters;

  plend ()

(** [create_2d_graph] outputs a file with a graph in 2D *)
let create_2d_graph filename points clusters colors distance_metric =
  let max_x = ref (-.max_float) in
  let min_x = ref max_float in
  let max_y = ref (-.max_float) in
  let min_y = ref max_float in

  let x = Array.make (List.length points) 0.0 in
  let y = Array.make (List.length points) 0.0 in

  for i = 0 to List.length points - 1 do
    let coords = GroupProject.Point.get_coordinates (List.nth points i) in
    let curr_x = List.nth coords 0 in
    let curr_y = List.nth coords 1 in
    x.(i) <- curr_x;
    y.(i) <- curr_y;
    min_x := min !min_x curr_x;
    max_x := max !max_x curr_x;
    min_y := min !min_y curr_y;
    max_y := max !max_y curr_y
  done;

  let open Plplot in
  plsdev "png";
  plsfnam filename;
  plinit ();

  Array.iteri
    (fun i (_, (r, g, b)) ->
      plscol0 (i + 1)
        (int_of_float (r *. 255.))
        (int_of_float (g *. 255.))
        (int_of_float (b *. 255.)))
    colors;

  plscol0 (Array.length colors + 1) 255 255 255;
  plcol0 (Array.length colors + 1);

  let x_range = !max_x -. !min_x in
  let y_range = !max_y -. !min_y in

  plenv
    (!min_x -. (0.1 *. x_range))
    (!max_x +. (0.1 *. x_range))
    (!min_y -. (0.1 *. y_range))
    (!max_y +. (0.1 *. y_range))
    0 0;
  pllab "X-axis" "Y-axis" "2D Graph";

  List.iteri
    (fun i cluster_point ->
      let color_index = (i mod Array.length colors) + 1 in
      plcol0 color_index;

      let cluster_points =
        List.filter
          (fun p ->
            let curr_dist = distance_metric p cluster_point in
            List.for_all
              (fun other_cluster ->
                curr_dist <= distance_metric p other_cluster)
              clusters)
          points
      in

      let x_cluster_points =
        Array.of_list
          (List.map
             (fun p -> List.nth (GroupProject.Point.get_coordinates p) 0)
             cluster_points)
      in
      let y_cluster_points =
        Array.of_list
          (List.map
             (fun p -> List.nth (GroupProject.Point.get_coordinates p) 1)
             cluster_points)
      in

      plpoin x_cluster_points y_cluster_points 9;

      let center_coords = GroupProject.Point.get_coordinates cluster_point in
      let cx = List.nth center_coords 0 in
      let cy = List.nth center_coords 1 in
      plcol0 (Array.length colors + 1);
      plpoin [| cx |] [| cy |] 5)
    clusters;

  plend ()

(** [create_3d_graph] outputs a file with a graph in 3D *)
let create_3d_graph filename points clusters colors distance_metric =
  let max_x = ref (-.max_float) and min_x = ref max_float in
  let max_y = ref (-.max_float) and min_y = ref max_float in
  let max_z = ref (-.max_float) and min_z = ref max_float in

  let x = Array.make (List.length points) 0.0 in
  let y = Array.make (List.length points) 0.0 in
  let z = Array.make (List.length points) 0.0 in

  List.iteri
    (fun i p ->
      let coords = GroupProject.Point.get_coordinates p in
      let curr_x, curr_y, curr_z =
        (List.nth coords 0, List.nth coords 1, List.nth coords 2)
      in
      x.(i) <- curr_x;
      y.(i) <- curr_y;
      z.(i) <- curr_z;
      min_x := min !min_x curr_x;
      max_x := max !max_x curr_x;
      min_y := min !min_y curr_y;
      max_y := max !max_y curr_y;
      min_z := min !min_z curr_z;
      max_z := max !max_z curr_z)
    points;

  let open Plplot in
  plsdev "png";
  plsfnam filename;
  plinit ();

  Array.iteri
    (fun i (_, (r, g, b)) ->
      plscol0 (i + 1)
        (int_of_float (r *. 255.))
        (int_of_float (g *. 255.))
        (int_of_float (b *. 255.)))
    colors;

  let x_range = !max_x -. !min_x in
  let y_range = !max_y -. !min_y in
  let z_range = !max_z -. !min_z in

  let scale_factor = 5.0 in

  plscol0 (Array.length colors + 1) 0 0 0;
  plscol0 (Array.length colors + 2) 255 255 255;

  plcol0 (Array.length colors + 1);

  plenv
    (-0.15 *. x_range *. scale_factor)
    (0.15 *. x_range *. scale_factor)
    (-0.15 *. y_range *. scale_factor)
    (0.15 *. y_range *. scale_factor)
    0 0;

  plw3d (1.0 *. scale_factor) (1.0 *. scale_factor) (1.0 *. scale_factor)
    (!min_x -. (0.15 *. x_range))
    (!max_x +. (0.15 *. x_range))
    (!min_y -. (0.15 *. y_range))
    (!max_y +. (0.15 *. y_range))
    (!min_z -. (0.15 *. z_range))
    (!max_z +. (0.15 *. z_range))
    30.0 30.0;

  plcol0 (Array.length colors + 2);
  plbox3 "bnstu" "X-axis" 0.0 0 "bnstu" "Y-axis" 0.0 0 "bcdmnstuv" "Z-axis" 0.0
    0;

  plpoin3 x y z 9;

  List.iteri
    (fun i cluster ->
      let color_index = (i mod Array.length colors) + 1 in
      plcol0 color_index;

      let cluster_points =
        List.filter
          (fun p ->
            let curr_dist = distance_metric p cluster in
            List.for_all
              (fun other_cluster ->
                curr_dist <= distance_metric p other_cluster)
              clusters)
          points
      in

      let x_cluster_points =
        Array.of_list
          (List.map
             (fun p -> List.nth (GroupProject.Point.get_coordinates p) 0)
             cluster_points)
      in
      let y_cluster_points =
        Array.of_list
          (List.map
             (fun p -> List.nth (GroupProject.Point.get_coordinates p) 1)
             cluster_points)
      in
      let z_cluster_points =
        Array.of_list
          (List.map
             (fun p -> List.nth (GroupProject.Point.get_coordinates p) 2)
             cluster_points)
      in

      plpoin3 x_cluster_points y_cluster_points z_cluster_points 9;

      let center_coords = GroupProject.Point.get_coordinates cluster in
      let cx = List.nth center_coords 0 in
      let cy = List.nth center_coords 1 in
      let cz = List.nth center_coords 2 in
      plcol0 (Array.length colors + 2);
      plpoin3 [| cx |] [| cy |] [| cz |] 5)
    clusters;

  plend ()

(** [plot_graph] chooses the graph function to run and runs it *)
let plot_graph view points clusters colors distance_metric () =
  let filename = "pictures/graph.png" in
  match view with
  | "1D" -> create_1d_graph filename points clusters colors distance_metric
  | "2D" -> create_2d_graph filename points clusters colors distance_metric
  | "3D" -> create_3d_graph filename points clusters colors distance_metric
  | _ -> failwith "Unsupported visualization type"

(** [create_plot_window] creates a window for the plot to be shown *)
let create_plot_window window graph_box image_path =
  GMisc.image ~file:image_path ~packing:graph_box#add ()

(* -------------------------------------------------------------------------- *)
(* GUI FUNCTIONALITY *)
(* -------------------------------------------------------------------------- *)

(** [initialize_gui] loads in all of the GUI for our project, including the many
    screens *)
let initialize_gui () =
  let init = GMain.init () in
  ignore init;

  let window = GWindow.window ~title:"CamelClass" ~show:true () in
  window#maximize ();

  let choice = ref "" in
  let chosen_colors = ref [||] in
  let current_metric_path = ref GroupProject.Point.euclidean_distance in

  let fixed = GPack.fixed ~packing:window#add () in

  let cwd = Sys.getcwd () in
  let bg_file = Filename.concat cwd "pictures/desertcamelkmeans.png" in
  let screen_width = Gdk.Screen.width () in
  let screen_height = Gdk.Screen.height () in
  let pixbuf =
    GdkPixbuf.from_file_at_size bg_file ~width:screen_width
      ~height:screen_height
  in
  let _background = GMisc.image ~pixbuf ~packing:(fixed#put ~x:0 ~y:0) () in

  let text_width, text_height = (600, 200) in
  let button_width, button_height = (200, 80) in
  let center_x = (screen_width - text_width) / 2 in
  let center_y = (screen_height - text_height - button_height) / 2 in

  let project_title =
    GMisc.label ~markup:"<span size='100000'><b>CamelClass</b></span>"
      ~selectable:false ~xalign:0.5 ~yalign:0.0 ()
  in
  fixed#put
    ~x:(int_of_float (float_of_int center_x +. (0.1 *. float_of_int center_x)))
    ~y:(center_y - 50) project_title#coerce;

  let project_subtitle =
    GMisc.label ~markup:"<span size='35000'>K-means Clustering</span>"
      ~selectable:false ~xalign:0.5 ~yalign:0.0 ()
  in
  fixed#put
    ~x:(int_of_float (float_of_int center_x +. (0.3 *. float_of_int center_x)))
    ~y:(center_y + 75) project_subtitle#coerce;

  let start_button = GButton.button ~label:"Start" () in
  start_button#misc#set_size_request ~width:button_width ~height:button_height
    ();
  let font = GPango.font_description_from_string "Arial 20" in
  start_button#misc#modify_font font;
  fixed#put
    ~x:((screen_width - button_width) / 2)
    ~y:(center_y + text_height) start_button#coerce;

  (* Cleaning the existing window*)
  let clean (window : GWindow.window) =
    match window#children with
    | [] -> ()
    | children -> List.iter (fun widget -> widget#destroy ()) children
  in

  (* -------------------------------------------------------------------------- *)
  (* GUI TRANSITIONS *)
  (* -------------------------------------------------------------------------- *)
  let rec start () =
    (* Clean existing window *)
    clean window;

    let screen_width = Gdk.Screen.width () in
    let screen_height = Gdk.Screen.height () in

    let main_box_width = 600 in
    let main_box_height = 600 in

    let center_x = (screen_width - main_box_width) / 2 in
    let center_y = (screen_height - main_box_height) / 2 in

    let fixed = GPack.fixed ~packing:window#add () in

    (* Load in a background image to the bakground *)
    let cwd = Sys.getcwd () in
    let bg_file = Filename.concat cwd "pictures/desertcamelkmeans.png" in
    let pixbuf =
      GdkPixbuf.from_file_at_size bg_file ~width:screen_width
        ~height:screen_height
    in
    ignore (GMisc.image ~pixbuf ~packing:(fixed#put ~x:0 ~y:0) ());

    let main_box =
      GPack.vbox ~spacing:20 ~border_width:20
        ~packing:(fixed#put ~x:center_x ~y:center_y)
        ()
    in

    let intro_label =
      GMisc.label
        ~markup:
          "<span size='50000' weight='bold'>Welcome to CamelClass!</span>\n\
           <span size='40000'>  Please select an action below:</span>"
        ~xalign:0.5 ~yalign:0.5
        ~packing:(main_box#pack ~expand:false ~fill:false ~padding:10)
        ()
    in
    intro_label#misc#show ();

    let controls_box =
      GPack.vbox ~width:60 ~height:300
        ~packing:(main_box#pack ~expand:true ~fill:true)
        ~spacing:20 ~border_width:100 ()
    in
    controls_box#set_homogeneous false;

    let font = GPango.font_description_from_string "Arial 20" in

    (* Add buttons for choosing the next action *)
    let choose_file_button =
      GButton.button ~label:"Choose File"
        ~packing:(controls_box#pack ~expand:true ~fill:true)
        ()
    in
    choose_file_button#misc#set_size_request ~height:50 ~width:200 ();
    choose_file_button#misc#modify_font font;

    let sample_points_button =
      GButton.button ~label:"Sample Points"
        ~packing:(controls_box#pack ~expand:true ~fill:true)
        ()
    in
    sample_points_button#misc#set_size_request ~height:50 ~width:200 ();
    sample_points_button#misc#modify_font font;

    let random_points_button =
      GButton.button ~label:"Random Points"
        ~packing:(controls_box#pack ~expand:true ~fill:true)
        ()
    in
    random_points_button#misc#set_size_request ~height:50 ~width:200 ();
    random_points_button#misc#modify_font font;

    window#misc#show_all ();

    ignore
      (choose_file_button#connect#clicked ~callback:(fun () ->
           choice := "file";
           transition3 ()));
    ignore
      (sample_points_button#connect#clicked ~callback:(fun () ->
           choice := "sample";
           transition3 ()));
    ignore
      (random_points_button#connect#clicked ~callback:(fun () ->
           choice := "random";
           generate ();
           transition3 ()))
  and transition3 () =
    (* Transition 3: After file selection *)
    clean window;
    let vbox = GPack.vbox ~packing:window#add () in

    let screen_width = Gdk.Screen.width () in
    let screen_height = Gdk.Screen.height () in

    let title_height = int_of_float (0.05 *. float_of_int screen_height) in

    let title_box = GPack.vbox ~packing:vbox#add ~spacing:5 () in
    title_box#misc#set_size_request ~width:screen_width ~height:title_height ();

    let _divider =
      GMisc.separator `HORIZONTAL
        ~packing:(vbox#pack ~expand:false ~fill:true)
        ()
    in
    _divider#misc#set_size_request ~height:2 ();

    let _top_indent =
      GMisc.label ~text:"" ~height:10
        ~packing:(title_box#pack ~expand:false ~fill:false)
        ()
    in

    let _project_title =
      GMisc.label ~markup:"<span size='50000'><b>CamelClass</b></span>"
        ~selectable:false ~xalign:0.5 ~yalign:0.5
        ~packing:(title_box#pack ~expand:false ~fill:false)
        ()
    in

    let _project_subtitle =
      GMisc.label ~markup:"<span size='15000'>K-means Clustering</span>"
        ~selectable:false ~xalign:0.5 ~yalign:0.5
        ~packing:(title_box#pack ~expand:false ~fill:false)
        ()
    in

    let main_area = GPack.hbox ~packing:vbox#add () in
    let menu_area =
      GPack.vbox ~packing:main_area#add ~spacing:5 ~border_width:10 ()
    in
    let _menu_divider =
      GMisc.separator `VERTICAL
        ~packing:(main_area#pack ~expand:false ~fill:true)
        ()
    in
    _menu_divider#misc#set_size_request ~width:2 ();
    let plot_and_log_area =
      GPack.vbox ~packing:main_area#add ~spacing:5 ~border_width:10 ()
    in

    let _logsubtitle =
      GMisc.label
        ~markup:
          "<span size='40000' weight='bold' underline='single'>Menu</span>"
        ~selectable:false ~xalign:0.5 ~yalign:0.5
        ~packing:(menu_area#pack ~expand:false ~fill:false)
        ()
    in

    let _logindent =
      GMisc.label
        ~markup:"<span size='15000' weight='bold' underline='single'> </span>"
        ~selectable:false ~xalign:0.5 ~yalign:0.5
        ~packing:(menu_area#pack ~expand:false ~fill:false)
        ()
    in

    let controls_box = GPack.vbox ~packing:menu_area#pack ~spacing:10 () in

    (* File selection section *)
    let open_file_box = GPack.hbox ~packing:controls_box#pack ~spacing:5 () in

    let file_button =
      GButton.button ~label:"Open File" ~packing:open_file_box#pack ()
    in
    file_button#misc#set_size_request ~width:200 ();

    let file_label_box = GPack.vbox ~packing:open_file_box#pack ~spacing:5 () in

    let _selected_file_label =
      GMisc.label
        ~markup:
          "<span size='15000' weight='bold' underline='single'>Selected \
           File</span>"
        ~selectable:false ~xalign:0.0 ~yalign:0.0
        ~packing:(file_label_box#pack ~expand:false ~fill:false)
        ()
    in

    let file_name_label =
      GMisc.label ~text:"None" ~xalign:0.0 ~yalign:0.0
        ~packing:(file_label_box#pack ~expand:false ~fill:false)
        ()
    in

    (* K selection section *)
    let k_box = GPack.hbox ~packing:controls_box#pack () ~spacing:10 in
    let _ =
      GMisc.label ~markup:"<span size='15000' weight='bold'>K-Value:</span>"
        ~packing:k_box#pack ()
    in
    let k_spin =
      GEdit.spin_button ~packing:k_box#pack ~digits:0 ~numeric:true ~wrap:true
        ()
    in
    k_spin#adjustment#set_bounds ~lower:1. ~upper:10.0 ~step_incr:1. ();
    k_spin#set_value 3.;

    (* Store current points and dimension *)
    let current_points = ref [] in
    let current_dim = ref 0 in
    let current_k = ref 3 in

    (* Distance metric selection section *)
    let metric_box = GPack.hbox ~packing:controls_box#pack () in
    let _ =
      GMisc.label
        ~markup:"<span size='15000' weight='bold'>Distance Metric:</span>"
        ~packing:metric_box#pack ()
    in
    let radio_euclidean =
      GButton.radio_button ~label:"Euclidean" ~packing:metric_box#pack ()
    in
    let radio_manhattan =
      GButton.radio_button ~group:radio_euclidean#group ~label:"Manhattan"
        ~packing:metric_box#pack ()
    in

    (* Color selection section *)
    let cluster_colors_box =
      GPack.vbox ~packing:controls_box#pack ~spacing:5 ()
    in

    let cluster_colors_label =
      GMisc.label
        ~markup:
          (Printf.sprintf
             "<span size='15000' weight='bold'>Cluster Colors:</span>\n\
              <span size='15000'>Choose up to %d colors</span>"
             !current_k)
        ~packing:cluster_colors_box#pack () ~selectable:false ~xalign:0.0
        ~yalign:0.0
    in

    (* Define a square *)
    let square_dims = [ (10, 10); (60, 10); (60, 60); (10, 60); (10, 10) ] in

    let colors =
      [|
        ("red", (1.0, 0.0, 0.0));
        ("orange", (1.0, 0.5, 0.0));
        ("gold", (1.0, 0.84, 0.0));
        ("yellow", (1.0, 1.0, 0.0));
        ("green", (0.0, 1.0, 0.0));
        ("cyan", (0.0, 1.0, 1.0));
        ("blue", (0.0, 0.0, 1.0));
        ("purple", (0.5, 0.0, 0.5));
        ("pink", (1.0, 0.0, 1.0));
        ("brown", (0.65, 0.16, 0.16));
        ("gray", (0.5, 0.5, 0.5));
        ("silver", (0.75, 0.75, 0.75));
      |]
    in

    (* Define a hashtable to check which colors were clicked *)
    let selected_squares = Hashtbl.create 10 in

    (* [draw_square] draws the square on the window by using the provided
       points *)
    let draw_square cr points (r, g, b) =
      match points with
      | [] -> ()
      | (x, y) :: tl ->
          Cairo.move_to cr (float x) (float y);
          List.iter (fun (x, y) -> Cairo.line_to cr (float x) (float y)) tl;
          Cairo.set_source_rgb cr r g b;
          Cairo.fill cr
    in

    (* [draw] draws the square on the canvas *)
    let draw square (name, (r, g, b)) (cr : Cairo.context) =
      draw_square cr square_dims (r, g, b);

      (* Check if this square is selected. If it is, add an overlay that says
         "selected"*)
      if Hashtbl.mem selected_squares name then (
        Cairo.set_source_rgba cr 1.0 1.0 1.0 0.6;
        Cairo.rectangle cr 10.0 10.0 ~w:50.0 ~h:50.0;
        Cairo.fill cr;

        Cairo.set_source_rgb cr 0.0 0.0 0.0;
        Cairo.select_font_face cr "Sans" ~weight:Bold;
        Cairo.set_font_size cr 10.0;
        Cairo.move_to cr 16.0 40.0;
        Cairo.show_text cr "Selected";
        Cairo.stroke cr);
      true
    in

    (* [square_selected] marks a square as selected when it is clicked on *)
    let square_selected name color square =
      (if Hashtbl.mem selected_squares name then (
         chosen_colors :=
           !chosen_colors |> Array.to_list
           |> List.filter (fun (n, _) -> n <> name)
           |> Array.of_list;
         Hashtbl.remove selected_squares name)
       else
         let k = int_of_float k_spin#value in
         if Array.length !chosen_colors < k then (
           chosen_colors := Array.append !chosen_colors [| (name, color) |];
           Hashtbl.add selected_squares name ()));
      square#misc#queue_draw ();
      false
    in

    let grid =
      GPack.table ~rows:2 ~columns:6 ~homogeneous:true
        ~packing:cluster_colors_box#pack ()
    in

    (* Go through all the colors in the array to make the grid *)
    Array.iteri
      (fun idx (name, color) ->
        let row = idx / 6 in
        let col = idx mod 6 in

        let square =
          GMisc.drawing_area ~packing:(grid#attach ~left:col ~top:row) ()
        in
        square#misc#set_size_request ~width:70 ~height:70 ();

        square#event#add [ `BUTTON_PRESS ];

        (* Make a square with the next color in the array, and make it
           selectable *)
        ignore (square#misc#connect#draw ~callback:(draw square (name, color)));
        ignore
          (square#event#connect#button_press ~callback:(fun _ ->
               square_selected name color square)))
      colors;

    (* Running K-Means Button Section *)
    let _divider =
      GMisc.separator `HORIZONTAL
        ~packing:(menu_area#pack ~expand:false ~fill:true)
        ()
    in
    _divider#misc#set_size_request ~height:2 ();

    let run_kmeans_button_area =
      GPack.vbox ~packing:menu_area#pack ~spacing:10 ()
    in

    let run_button =
      GButton.button ~label:"Run K-means" ~packing:run_kmeans_button_area#pack
        ()
    in

    (* Graph Section *)
    let graph_box_height = int_of_float (0.6 *. float_of_int screen_height) in
    let graph_box_width = int_of_float (0.6 *. float_of_int screen_width) in

    let graph_box = GPack.box `HORIZONTAL ~packing:plot_and_log_area#pack () in
    let () =
      graph_box#misc#set_size_request ~width:graph_box_width
        ~height:graph_box_height ()
    in
    let graph_image =
      GMisc.image ~file:"pictures/no_graph.png" ~packing:graph_box#add ()
    in
    let next_button = GButton.button ~label:"Next ▶" ~packing:vbox#pack () in

    (* Disable the next button initially until K-Means has been run *)
    next_button#misc#set_sensitive false;

    let _divider =
      GMisc.separator `HORIZONTAL
        ~packing:(plot_and_log_area#pack ~expand:false ~fill:true)
        ()
    in
    _divider#misc#set_size_request ~height:2 ();

    let log_area = GPack.vbox ~packing:plot_and_log_area#add ~spacing:5 () in

    let _logsubtitle =
      GMisc.label
        ~markup:
          "<span size='30000' weight='bold' underline='single'>Log \
           (scrollable)</span>"
        ~selectable:false ~xalign:0.0 ~yalign:0.5
        ~packing:(log_area#pack ~expand:false ~fill:false)
        ()
    in

    (* Section for messages log *)
    let scroll_view_height = int_of_float (0.4 *. float_of_int screen_height) in
    let scroll_view_width = int_of_float (0.6 *. float_of_int screen_width) in

    let scrolled_window =
      GBin.scrolled_window ~hpolicy:`AUTOMATIC ~vpolicy:`AUTOMATIC
        ~packing:(log_area#pack ~expand:true ~fill:true)
        ()
    in
    let text_view = GText.view ~packing:scrolled_window#add () in
    let () =
      text_view#misc#set_size_request ~width:scroll_view_width
        ~height:scroll_view_height ()
    in

    let buffer = text_view#buffer in

    (* Auto-scroll function *)
    let auto_scroll () =
      let scroll_to_bottom () =
        let end_iter = buffer#end_iter in
        ignore
          (text_view#scroll_to_iter end_iter ~within_margin:0.1 ~use_align:true
             ~xalign:0.0 ~yalign:1.0);
        buffer#place_cursor ~where:end_iter;
        false
      in
      ignore (GMain.Idle.add scroll_to_bottom)
    in

    (* Update current_k when k_spin value changes *)
    ignore
      (k_spin#connect#value_changed ~callback:(fun () ->
           current_k := int_of_float k_spin#value;

           (* Update the cluster colors label to reflect the change of k *)
           let markup_text =
             Printf.sprintf
               "<span size='15000' weight='bold'>Cluster Colors:</span>\n\
                <span size='15000'>Choose up to %d colors</span>"
               !current_k
           in
           cluster_colors_label#set_label markup_text));

    let current_metric = ref "Euclidean" in

    (* Optimize K button section *)
    let optimize_k_box = GPack.hbox ~packing:controls_box#pack ~spacing:10 () in
    let optimize_k_button =
      GButton.button ~label:"Optimize K" ~packing:optimize_k_box#pack ()
    in
    let optimize_k_handler () =
      if List.length !current_points = 0 then begin
        buffer#insert "\nNo points loaded. Please select a file first.\n";
        auto_scroll ()
      end
      else
        let points = !current_points in
        let num_points = List.length points in
        let dist_fn =
          if radio_euclidean#active then euclidean_distance
          else manhattan_distance
        in

        buffer#insert "\nCalculating optimal K value...\n";
        auto_scroll ();

        (* Run k-means for a range up to min(6, num_points) *)
        let max_k = min 6 num_points in
        buffer#insert
          (Printf.sprintf "Testing different k values (2 to %d)...\n" max_k);
        auto_scroll ();
        let cluster_sets = ref [] in

        (* Try each k value individually and update progress *)
        for k = 2 to max_k do
          buffer#insert (Printf.sprintf "Testing k=%d...\n" k);
          auto_scroll ();
          try
            let clusters = run_kmeans k points dist_fn in
            cluster_sets := clusters :: !cluster_sets;
            buffer#insert (Printf.sprintf "Completed k=%d\n" k);
            auto_scroll ()
          with Invalid_argument _ ->
            buffer#insert
              (Printf.sprintf "Skipped k=%d (not enough points)\n" k);
            auto_scroll ()
        done;

        if List.length !cluster_sets = 0 then
          buffer#insert
            "\nCould not find optimal k value. Try with more data points.\n"
        else begin
          buffer#insert "Calculating best k value...\n";
          auto_scroll ();
          let best_k = find_best_k (List.rev !cluster_sets) points dist_fn in

          (* Display final result *)
          buffer#insert (Printf.sprintf "\nOptimal K value found: %d\n" best_k);
          auto_scroll ();

          (* Update the k-spin value *)
          k_spin#set_value (float_of_int best_k);

          buffer#insert "Done! The k-value has been updated.\n";
          auto_scroll ()
        end
    in
    ignore (optimize_k_button#connect#clicked ~callback:optimize_k_handler);

    (* [on_metric_changed] updates the current metric to be used by the K-Means
       model *)
    let on_metric_changed () =
      current_metric :=
        if radio_euclidean#active then (
          current_metric_path := GroupProject.Point.euclidean_distance;
          "Euclidean")
        else (
          current_metric_path := GroupProject.Point.manhattan_distance;
          "Manhattan");
      buffer#insert ("\nDistance metric changed to: " ^ !current_metric ^ "\n");
      auto_scroll ()
    in

    (* -------------------------------------------------------------------------- *)
    (* FILE HANDLING *)
    (* -------------------------------------------------------------------------- *)

    (* [open_file] opens an existing csv file of the user's choice *)
    let open_file () =
      let dialog =
        GWindow.file_chooser_dialog ~action:`OPEN ~title:"Select CSV File"
          ~parent:window ~position:`CENTER_ON_PARENT ()
      in

      dialog#add_button_stock `OPEN `OPEN;
      dialog#add_button_stock `CANCEL `CANCEL;

      let filter = GFile.filter ~name:"CSV Files" () in
      filter#add_pattern "*.csv";
      dialog#add_filter filter;

      let result = dialog#run () in
      let filename = dialog#filename in
      dialog#destroy ();

      match result with
      | `OPEN -> (
          match filename with
          | Some file -> (
              let file_basename = Filename.basename file in
              buffer#set_text ("Loading file: " ^ file ^ "\n");
              auto_scroll ();
              file_name_label#set_text file_basename;
              try
                let csv = Csv.load file in
                let first_line = List.hd csv in
                let dim = List.length first_line in
                current_dim := dim;
                current_points := read_points dim file;

                buffer#insert
                  ("Successfully loaded "
                  ^ string_of_int (List.length !current_points)
                  ^ " points of dimension " ^ string_of_int dim ^ "\n\n"
                  ^ "Few Sample points:\n");
                auto_scroll ();

                let rec show_n_points points n =
                  match (points, n) with
                  | [], _ -> ()
                  | _, 0 -> ()
                  | p :: ps, n ->
                      buffer#insert (GroupProject.Point.to_string p ^ "\n");
                      auto_scroll ();
                      show_n_points ps (n - 1)
                in
                show_n_points !current_points 5;

                if dim > 3 then
                  buffer#insert
                    "\n\
                     Note: Points are greater than 3D. Visualization will not \
                     be available.\n";
                auto_scroll ();

                run_button#misc#set_sensitive true
              with e ->
                buffer#set_text
                  ("Error reading file: " ^ Printexc.to_string e ^ "\n");
                auto_scroll ();
                run_button#misc#set_sensitive false)
          | None ->
              buffer#set_text "No file selected.\n";
              auto_scroll ();
              file_name_label#set_text "None";
              run_button#misc#set_sensitive false)
      | `CANCEL | `DELETE_EVENT ->
          buffer#set_text "File selection cancelled.\n";
          auto_scroll ();
          run_button#misc#set_sensitive false
    in

    (* [open_sample_file] opens the provided sample file *)
    let open_sample_file () =
      buffer#set_text "You selected points from a sample file.\n";
      auto_scroll ();
      let cwd = Sys.getcwd () in
      let sample_filename = Filename.concat cwd "data/sample.csv" in

      let file_basename = Filename.basename sample_filename in
      buffer#insert ("Loading file: " ^ sample_filename ^ "\n");
      auto_scroll ();
      file_name_label#set_text file_basename;
      let csv = Csv.load sample_filename in
      let first_line = List.hd csv in
      let dim = List.length first_line in
      current_dim := dim;
      current_points := read_points dim sample_filename;

      buffer#insert
        ("Successfully loaded "
        ^ string_of_int (List.length !current_points)
        ^ " points of dimension " ^ string_of_int dim ^ "\n\n"
        ^ "Your points:\n");
      auto_scroll ();

      let rec show_n_points points n =
        match (points, n) with
        | [], _ -> ()
        | _, 0 -> ()
        | p :: ps, n ->
            buffer#insert (GroupProject.Point.to_string p ^ "\n");
            auto_scroll ();
            show_n_points ps (n - 1)
      in
      show_n_points !current_points (List.length !current_points);
      run_button#misc#set_sensitive true
    in

    (* [open_random_file] creates a new csv file of random points and opens it*)
    let open_random_file () =
      buffer#set_text "You selected points from a random points generator.\n";
      auto_scroll ();

      let cwd = Sys.getcwd () in
      let random_filename = Filename.concat cwd "data/random.csv" in

      let file_basename = Filename.basename random_filename in
      buffer#insert ("Loading file: " ^ random_filename ^ "\n");
      auto_scroll ();
      file_name_label#set_text file_basename;
      let csv = Csv.load random_filename in
      let first_line = List.hd csv in
      let dim = List.length first_line in
      current_dim := dim;
      current_points := read_points dim random_filename;

      buffer#insert
        ("Successfully loaded "
        ^ string_of_int (List.length !current_points)
        ^ " points of dimension " ^ string_of_int dim ^ "\n\n"
        ^ "Few Sample points:\n");
      auto_scroll ();

      let rec show_n_points points n =
        match (points, n) with
        | [], _ -> ()
        | _, 0 -> ()
        | p :: ps, n ->
            buffer#insert (GroupProject.Point.to_string p ^ "\n");
            auto_scroll ();
            show_n_points ps (n - 1)
      in
      show_n_points !current_points 5;
      run_button#misc#set_sensitive true
    in

    (* Functions below to call the plotting of the graph in the respective
       dimensional view *)
    let create_2d_graph filename (points : t list) clusters colors
        distance_metric =
      create_2d_graph filename points clusters colors distance_metric
    in

    let create_1d_graph filename (points : t list) clusters colors
        distance_metric =
      create_1d_graph filename points clusters colors distance_metric
    in

    let create_3d_graph filename (points : t list) clusters colors
        distance_metric =
      create_3d_graph filename points clusters colors distance_metric
    in

    let plot_graph view points clusters colors distance_metric () =
      let filename = "pictures/graph.png" in
      if view = "1D" then
        create_1d_graph filename points clusters colors distance_metric
      else if view = "2D" then
        create_2d_graph filename points clusters colors distance_metric
      else create_3d_graph filename points clusters colors distance_metric
    in

    (* -------------------------------------------------------------------------- *)
    (* CLUSTERING LOGIC *)
    (* -------------------------------------------------------------------------- *)

    (* Runs the K-means algorithm *)
    let run_kmeans () =
      match !current_points with
      | [] ->
          buffer#insert "\nNo points loaded. Please select a file first.\n";
          auto_scroll ()
      | points ->
          (try
             let dist_fn =
               if radio_euclidean#active then euclidean_distance
               else manhattan_distance
             in
             buffer#insert ("Using " ^ !current_metric ^ " distance metric.\n");
             auto_scroll ();
             let clusters = run_custom_kmeans !current_k points dist_fn in
             buffer#insert "Clustering completed.\n";
             auto_scroll ();

             (* [select_random_colors] selects random colors from the list of
                colors to autofill user choices *)
             let select_random_colors chosen_colors defined_colors k =
               let chosen_list = Array.to_list chosen_colors in

               let remaining_colors =
                 Array.to_list defined_colors
                 |> List.filter (fun (name, _) ->
                        not (List.mem_assoc name chosen_list))
               in

               let rec pick_random_elements acc colors n =
                 if n <= 0 || colors = [] then acc
                 else
                   let idx = Random.int (List.length colors) in
                   let chosen_color = List.nth colors idx in
                   let new_colors =
                     List.filter (fun x -> x <> chosen_color) colors
                   in
                   pick_random_elements (chosen_color :: acc) new_colors (n - 1)
               in

               (* Randomly select the amount of colors needed to meet k and add
                  to the list of already chosen colors *)
               let needed_count = max 0 (k - Array.length chosen_colors) in
               let additional_colors =
                 pick_random_elements [] remaining_colors needed_count
               in
               Array.append chosen_colors (Array.of_list additional_colors)
             in

             let colors_to_use =
               if Array.length !chosen_colors < !current_k then
                 select_random_colors !chosen_colors colors !current_k
               else !chosen_colors
             in

             (* Run the correct graphing function according to the dimension *)
             if !current_dim == 1 then begin
               let _ =
                 plot_graph "1D" points clusters colors_to_use
                   !current_metric_path ()
               in
               buffer#insert "Visualization saved to 'graph.png'\n";
               auto_scroll ();
               graph_image#set_file "pictures/graph.png"
             end
             else if !current_dim == 2 then begin
               let _ =
                 plot_graph "2D" points clusters colors_to_use
                   !current_metric_path ()
               in
               buffer#insert "Visualization saved to 'graph.png'\n";
               auto_scroll ();
               graph_image#set_file "pictures/graph.png"
             end
             else if !current_dim == 3 then begin
               let _ =
                 plot_graph "3D" points clusters colors_to_use
                   !current_metric_path ()
               in
               buffer#insert "Visualization saved to 'graph.png'\n";
               auto_scroll ();
               graph_image#set_file "pictures/graph.png"
             end
             else
               buffer#insert
                 "Only points in the 1D, 2D, and 3D spaces can be graphed. \n";
             auto_scroll ();

             next_button#misc#set_sensitive true;

             List.iteri
               (fun i cluster ->
                 buffer#insert
                   ("Cluster "
                   ^ string_of_int (i + 1)
                   ^ " center: "
                   ^ GroupProject.Point.to_string cluster
                   ^ "\n");
                 auto_scroll ())
               clusters
           with e ->
             buffer#insert
               ("\nError during clustering: " ^ Printexc.to_string e ^ "\n"));
          auto_scroll ()
    in

    if !choice == "sample" then begin
      run_button#misc#set_sensitive true;
      file_button#misc#set_sensitive false;
      open_sample_file ()
    end
    else if !choice == "random" then begin
      run_button#misc#set_sensitive true;
      file_button#misc#set_sensitive false;
      open_random_file ()
    end
    else ignore (file_button#connect#clicked ~callback:open_file);
    ignore (radio_euclidean#connect#clicked ~callback:on_metric_changed);
    ignore (radio_manhattan#connect#clicked ~callback:on_metric_changed);
    ignore (run_button#connect#clicked ~callback:run_kmeans);
    ignore (window#connect#destroy ~callback:Main.quit);

    buffer#set_text "Welcome to CamelClass K-means Clustering\n\n";
    auto_scroll ();
    ignore
      (next_button#connect#clicked ~callback:(fun () ->
           transition4 !current_k !current_points))
  and transition4 current_k current_points =
    chosen_colors := [||];
    (* Transition 4: Show statistics *)
    clean window;

    let screen_width = Gdk.Screen.width () in
    let screen_height = Gdk.Screen.height () in

    let main_box_width = 800 in
    let main_box_height = 850 in

    let center_x = (screen_width - main_box_width) / 2 in
    let center_y = (screen_height - main_box_height) / 2 in

    let fixed = GPack.fixed ~packing:window#add () in

    let cwd = Sys.getcwd () in
    let bg_file = Filename.concat cwd "pictures/desertcamelkmeans.png" in
    let pixbuf =
      GdkPixbuf.from_file_at_size bg_file ~width:screen_width
        ~height:screen_height
    in

    ignore (GMisc.image ~pixbuf ~packing:(fixed#put ~x:0 ~y:0) ());

    let stats_box =
      GPack.vbox ~packing:(fixed#put ~x:center_x ~y:center_y) ()
    in

    let _statistics_title =
      GMisc.label
        ~markup:
          "<span size='50000'><b>K-Means Cluster Statistics \n\
          \ (Clusters are scrollable)</b></span>"
        ~selectable:true ~xalign:0.5 ~yalign:0.0 ~height:100
        ~packing:(stats_box#pack ~expand:true ~fill:false)
        ()
    in

    let clusters =
      run_custom_kmeans current_k current_points euclidean_distance
    in
    let cluster_stats_scroll =
      GBin.scrolled_window ~hpolicy:`AUTOMATIC ~vpolicy:`AUTOMATIC
        ~packing:(stats_box#pack ~expand:true ~fill:true)
        ()
    in
    cluster_stats_scroll#set_hpolicy `AUTOMATIC;
    let cluster_stats_box = GPack.vbox ~packing:stats_box#add ~spacing:10 () in
    cluster_stats_box#set_border_width 10;

    let total_points = List.length current_points in
    let _total_points_label =
      GMisc.label
        ~markup:
          ("<span size='20000'>Total Points: " ^ string_of_int total_points
         ^ "</span>")
        ~selectable:false ~xalign:0.5 ~yalign:0.5
        ~packing:(cluster_stats_box#pack ~expand:false ~fill:false ~padding:0)
        ()
    in

    let _cluster_count_label =
      GMisc.label
        ~markup:
          ("<span size='20000'>Number of Clusters: "
          ^ string_of_int (List.length clusters)
          ^ "</span>")
        ~selectable:false ~xalign:0.5 ~yalign:0.5
        ~packing:(cluster_stats_box#pack ~expand:false ~fill:false)
        ()
    in

    let total_variance =
      total_variation current_points clusters euclidean_distance
    in
    let _total_variance_label =
      GMisc.label
        ~markup:
          ("<span size='20000'>Total Variance: "
          ^ string_of_float total_variance
          ^ "</span>")
        ~selectable:false ~xalign:0.5 ~yalign:0.5
        ~packing:(cluster_stats_box#pack ~expand:false ~fill:false)
        ()
    in

    let _divider =
      GMisc.separator `HORIZONTAL
        ~packing:(cluster_stats_box#pack ~expand:false ~fill:true)
        ()
    in
    _divider#misc#set_size_request ~height:2 ();

    let scrolled_window =
      GBin.scrolled_window ~hpolicy:`AUTOMATIC ~vpolicy:`AUTOMATIC
        ~packing:(stats_box#pack ~expand:true ~fill:true)
        ()
    in
    let cluster_stats_box =
      GPack.vbox ~spacing:10 ~packing:scrolled_window#add ()
    in
    scrolled_window#misc#set_size_request ~width:800 ~height:400 ();

    (* Show the results of the K-Means algorithm by displaying the resulting
       clusters *)
    List.iteri
      (fun i cluster ->
        let cluster_points =
          let pts_in_cluster cluster clusters points dist_fn =
            List.filter
              (fun point ->
                List.for_all
                  (fun other_cluster ->
                    dist_fn point cluster <= dist_fn point other_cluster)
                  clusters)
              points
          in
          pts_in_cluster cluster clusters current_points euclidean_distance
        in
        let _cluster_label =
          GMisc.label
            ~markup:
              ("<span size='20000'><b>Cluster "
              ^ string_of_int (i + 1)
              ^ ":</b></span>")
            ~selectable:false ~xalign:0.5 ~yalign:0.5
            ~packing:(cluster_stats_box#pack ~expand:false ~fill:false)
            ()
        in
        let _cluster_size_label =
          GMisc.label
            ~markup:("Size: " ^ string_of_int (List.length cluster_points))
            ~selectable:false ~xalign:0.5 ~yalign:0.5
            ~packing:(cluster_stats_box#pack ~expand:false ~fill:false)
            ()
        in
        let _cluster_centroid_label =
          GMisc.label
            ~markup:("Centroid: " ^ GroupProject.Point.to_string cluster)
            ~selectable:false ~xalign:0.5 ~yalign:0.5
            ~packing:(cluster_stats_box#pack ~expand:false ~fill:false)
            ()
        in
        let cluster_points =
          let pts_in_cluster cluster clusters points dist_fn =
            List.filter
              (fun point ->
                List.for_all
                  (fun other_cluster ->
                    dist_fn point cluster <= dist_fn point other_cluster)
                  clusters)
              points
          in
          pts_in_cluster cluster clusters current_points euclidean_distance
        in
        let cluster_variance =
          List.fold_left
            (fun acc point ->
              let dist = euclidean_distance point cluster in
              acc +. (dist *. dist))
            0.0 cluster_points
        in
        let _cluster_variance_label =
          GMisc.label
            ~markup:("Variance: " ^ string_of_float cluster_variance)
            ~selectable:false ~xalign:0.5 ~yalign:0.5
            ~packing:(cluster_stats_box#pack ~expand:false ~fill:false)
            ()
        in
        ())
      clusters;

    let button_box =
      GPack.hbox ~spacing:20
        ~packing:(stats_box#pack ~expand:true ~fill:true)
        ()
    in

    (* Show the Next and Back buttons and make them look pretty with spacing *)
    let _left_spacer =
      GMisc.label ~text:"" ~packing:(button_box#pack ~expand:true ~fill:true) ()
    in

    let back_button =
      GButton.button ~label:"◀ Back"
        ~packing:(button_box#pack ~expand:false ~fill:false)
        ()
    in

    let next_button =
      GButton.button ~label:"Next ▶"
        ~packing:(button_box#pack ~expand:false ~fill:false)
        ()
    in

    let _right_spacer =
      GMisc.label ~text:"" ~packing:(button_box#pack ~expand:true ~fill:true) ()
    in

    let font = GPango.font_description_from_string "Arial 16" in
    back_button#misc#modify_font font;
    next_button#misc#modify_font font;
    back_button#set_relief `NORMAL;
    next_button#set_relief `NORMAL;
    back_button#misc#set_size_request ~width:200 ~height:(-1) ();
    next_button#misc#set_size_request ~width:200 ~height:(-1) ();

    ignore (back_button#connect#clicked ~callback:(fun () -> transition3 ()));
    ignore (next_button#connect#clicked ~callback:(fun () -> transition6 ()));

    window#misc#show_all ()
  and transition6 () =
    (* Transition 6: End Screen *)
    clean window;

    let screen_width = Gdk.Screen.width () in
    let screen_height = Gdk.Screen.height () in

    let main_box_width = 500 in
    let main_box_height = 500 in

    let center_x = (screen_width - main_box_width) / 2 in
    let center_y = (screen_height - main_box_height) / 2 in

    let fixed = GPack.fixed ~packing:window#add () in

    let cwd = Sys.getcwd () in
    let bg_file = Filename.concat cwd "pictures/desertcamelkmeans.png" in
    let pixbuf =
      GdkPixbuf.from_file_at_size bg_file ~width:screen_width
        ~height:screen_height
    in
    ignore (GMisc.image ~pixbuf ~packing:(fixed#put ~x:0 ~y:0) ());

    let controls_box =
      GPack.vbox ~width:60 ~height:400
        ~packing:(fixed#put ~x:center_x ~y:center_y)
        ~spacing:20 ~border_width:100 ()
    in
    controls_box#set_homogeneous false;

    let font = GPango.font_description_from_string "Arial 20" in

    let start_over_button =
      GButton.button ~label:"Start over"
        ~packing:(controls_box#pack ~expand:true ~fill:true)
        ()
    in
    start_over_button#misc#set_size_request ~height:70 ~width:300 ();
    start_over_button#misc#modify_font font;

    let quit_button =
      GButton.button ~label:"Quit"
        ~packing:(controls_box#pack ~expand:true ~fill:true)
        ()
    in
    quit_button#misc#set_size_request ~height:70 ~width:300 ();
    quit_button#misc#modify_font font;

    (* Restarts the program by allowing the user to run K-Means again *)
    let start_over () =
      choice := "file";
      chosen_colors := [||];
      start ()
    in

    let quit () =
      start ();
      clean window;

      let screen_width = Gdk.Screen.width () in
      let screen_height = Gdk.Screen.height () in

      let main_box_width = 1450 in
      let main_box_height = 800 in

      let center_x = (screen_width - main_box_width) / 2 in
      let center_y = (screen_height - main_box_height) / 2 in

      let fixed = GPack.fixed ~packing:window#add () in

      let cwd = Sys.getcwd () in
      let bg_file = Filename.concat cwd "pictures/desertcamelkmeans.png" in
      let pixbuf =
        GdkPixbuf.from_file_at_size bg_file ~width:screen_width
          ~height:screen_height
      in
      ignore (GMisc.image ~pixbuf ~packing:(fixed#put ~x:0 ~y:0) ());

      let controls_box =
        GPack.vbox ~spacing:5 ~border_width:20
          ~packing:(fixed#put ~x:center_x ~y:center_y)
          ()
      in
      controls_box#set_homogeneous false;

      (* Define a section for the Thank You portion of our project *)
      let _thanks_title =
        GMisc.label
          ~markup:
            "<span size='80000'><b>Thank you for your attention! </b></span>"
          ~selectable:true ~xalign:0.5 ~yalign:0.5
          ~packing:(controls_box#pack ~expand:false ~fill:false)
          ()
      in

      let _authors_title =
        GMisc.label ~markup:"<span size='30000'><b>\n\nAuthors: </b></span>"
          ~selectable:true ~xalign:0.5 ~yalign:1.0
          ~packing:(controls_box#pack ~expand:false ~fill:false)
          ()
      in

      let thanks_box =
        GPack.hbox ~spacing:20 ~border_width:50
          ~packing:(controls_box#pack ~expand:false ~fill:false)
          ()
      in

      let add_name name picture_file =
        let column =
          GPack.vbox ~spacing:5
            ~packing:(thanks_box#pack ~expand:false ~fill:false)
            ()
        in
        ignore (GMisc.label ~markup:name ~xalign:0.5 ~packing:column#add ());
        let pixbuf =
          GdkPixbuf.from_file_at_size picture_file ~width:200 ~height:200
        in
        ignore
          (GMisc.image ~pixbuf
             ~packing:(column#pack ~expand:false ~fill:false)
             ())
      in

      (* Add the names of the project authors *)
      let picture_file = Filename.concat cwd "pictures/camel1.jpeg" in
      add_name "<span size='30000'> Keti Sulamanidze </span>" picture_file;
      let divider =
        GMisc.separator `HORIZONTAL
          ~packing:(thanks_box#pack ~expand:false ~fill:true)
          ()
      in
      divider#misc#set_size_request ~height:4 ();

      let picture_file = Filename.concat cwd "pictures/camel2.jpeg" in
      add_name "<span size='30000'> Neha Naveen </span>" picture_file;
      let divider =
        GMisc.separator `HORIZONTAL
          ~packing:(thanks_box#pack ~expand:false ~fill:true)
          ()
      in
      divider#misc#set_size_request ~height:4 ();

      let picture_file = Filename.concat cwd "pictures/camel3.jpeg" in
      add_name "<span size='30000'> Ruby Penafiel-Gutierrez </span>"
        picture_file;
      let divider =
        GMisc.separator `HORIZONTAL
          ~packing:(thanks_box#pack ~expand:false ~fill:true)
          ()
      in
      divider#misc#set_size_request ~height:4 ();

      let picture_file = Filename.concat cwd "pictures/camel4.jpeg" in
      add_name "<span size='30000'> Samantha Vaca </span>" picture_file;
      let divider =
        GMisc.separator `HORIZONTAL
          ~packing:(thanks_box#pack ~expand:false ~fill:true)
          ()
      in
      divider#misc#set_size_request ~height:4 ();

      let picture_file = Filename.concat cwd "pictures/camel5.jpeg" in
      add_name "<span size='30000'> Varvara Babii </span>" picture_file;

      let quit_box =
        GPack.vbox ~spacing:5 ~border_width:0
          ~packing:(controls_box#pack ~expand:false ~fill:false)
          ()
      in

      let font = GPango.font_description_from_string "Arial 20" in

      let final_quit_button =
        GButton.button ~label:"Quit"
          ~packing:(quit_box#pack ~expand:false ~fill:false)
          ()
      in
      final_quit_button#misc#set_size_request ~height:50 ~width:10 ();
      final_quit_button#misc#modify_font font;

      window#misc#show_all ();
      ignore
        (final_quit_button#connect#clicked ~callback:(fun () ->
             window#destroy ()));
      Printf.printf "Visualization Complete. Thanks for your time! \n%!"
    in
    window#misc#show_all ();
    ignore (start_over_button#connect#clicked ~callback:start_over);
    ignore (quit_button#connect#clicked ~callback:quit)
  in
  ignore (start_button#connect#clicked ~callback:start);
  ignore (window#connect#destroy ~callback:GMain.quit);

  window#show ();
  GMain.main ()

(* -------------------------------------------------------------------------- *)
(* I/0 FUNCTIONALITY *)
(* -------------------------------------------------------------------------- *)

(* MARK: - Properties (Data) *)
let default_files = Hashtbl.create 10;;

Hashtbl.add default_files "./data/test_data.csv" 1;;
Hashtbl.add default_files "./data/test_data_2d.csv" 2;;
Hashtbl.add default_files "./data/test_data_3d.csv" 3

(* MARK: - Properties (Formatting and Display) *)

(** The type representing a color. *)
type color =
  | Red
  | Grn
  | Ylw
  | Blue
  | Magenta
  | Cyan
  | Wht

(** The type representing text styling options. *)
type style =
  | Bold
  | Und
  | Reg

(** [clr_ s c str] is the string [str] with style [s] and color [clr]. *)
let clr_ s c str =
  let clr =
    match c with
    | Red -> ANSITerminal.red
    | Grn -> ANSITerminal.green
    | Ylw -> ANSITerminal.yellow
    | Blue -> ANSITerminal.blue
    | Magenta -> ANSITerminal.magenta
    | Cyan -> ANSITerminal.cyan
    | _ -> ANSITerminal.white
  in
  match s with
  | Bold -> ANSITerminal.sprintf [ Bold; clr; ANSITerminal.on_black ] str
  | Und -> ANSITerminal.sprintf [ Underlined; clr; ANSITerminal.on_black ] str
  | Reg -> ANSITerminal.sprintf [ clr; ANSITerminal.on_black ] str

(* MARK: - Welcome Message *)

(** [welcome_ascii] is the programs ASCII art banner. *)
let welcome_ascii =
  clr_ Bold Grn
    "\n\
    \ __        _______ _     ____ ___  __  __ _____   _        \n\
    \ \\ \\      / / ____| |   / ___/ _ \\|  \\/  | ____| | |_ ___  \n\
    \  \\ \\ /\\ / /|  _| | |  | |  | | | | |\\/| |  _|   | __/ _ \\ \n\
    \   \\ V  V / | |___| |__| |__| |_| | |  | | |___  | || (_) |\n\
    \   _\\_/\\_/  |_____|_____\\____\\___/|_|  |_|_____|  \\__\\___/ \n\
    \  / ___|__ _ _ __ ___   ___| |/ ___| | __ _ ___ ___  | |   \n\
    \ | |   / _` | '_ ` _ \\ / _ \\ | |   | |/ _` / __/ __| | |   \n\
    \ | |__| (_| | | | | | |  __/ | |___| | (_| \\__ \\__ \\ |_|   \n\
    \  \\____\\__,_|_| |_| |_|\\___|_|\\____|_|\\__,_|___/___/ (_)   \n"

(* MARK: - Properties (Utilities) *)

(** [show_progress_bar task] declares the [task] being working on, displays a
    progress bar filled to 100% after 1 second, and lastly declares a success
    message. *)
let show_progress_bar task =
  Printf.printf "Working on: %s...\n%!" task;
  Unix.sleep 1;
  Printf.printf "%s 100%%\n" (clr_ Bold Blue "[##################]");
  Printf.printf "Task '%s' completed successfully!\n\n" task

(** [print_help ()] prints a list of actions the user can perform with the
    points from their CSV file. *)
let print_help () =
  let msg = clr_ Und Cyan "\nCommands that may be used:\n" in
  let display = clr_ Bold Ylw "points" in
  let distances = clr_ Bold Ylw "dists" in
  let kmeans = clr_ Bold Ylw "kmeans" in
  let help = clr_ Bold Ylw "help" in
  let exit = clr_ Bold Ylw "exit" in
  let reload = clr_ Bold Ylw "reload" in
  Printf.printf "%s" msg;
  Printf.printf "- %s : View all points from the CSV file.\n" display;
  Printf.printf
    "- %s : Compute distances between points using a selected metric.\n"
    distances;
  Printf.printf "- %s : Perform k-means. \n" kmeans;
  Printf.printf "- %s :  Load a new CSV file.\n" reload;
  Printf.printf "- %s : Display HELP message. \n" help;
  Printf.printf "- %s :  Exit the program. \n" exit

(* MARK: - Properties (Assurance) *)

(** [is_csv c] is whether or not [c] is a csv file. *)
let is_csv c =
  let len = String.length c in
  if len < 4 || String.sub c (len - 4) 4 <> ".csv" then begin
    Printf.printf "\nThis is not a valid csv file";
    false
  end
  else true

(** [is_dimension d] is whether or not [d] is a valid dimension. *)
let is_dimension d =
  try d > 0
  with _ ->
    Printf.printf
      "\n\
       This is an invalid coordinate: Try [1] [2] or  [N] where N is a \
       positive integer";
    false

(* MARK: - Properties (Metadata) *)

(** [get_dimension_from_csv csv] is the dimension of points in [csv]. *)
let get_dimension_from_csv csv =
  try
    let csv_data = Csv.load csv in
    let point_count = List.length csv_data in
    match csv_data with
    | row :: _ ->
        let dim = List.length row in
        if dim > 0 then Some (dim, point_count) else None
    | [] -> None
  with _ -> None

(* -------------------------------------------------------------------------- *)
(* Point Display Logic *)
(* -------------------------------------------------------------------------- *)

(** [print_points file d] prints the points of dimension [d] in [file]. *)
let print_points file d =
  try
    let p_list = List.map to_string (read_points d file) in
    List.iter (fun x -> Printf.printf "%s\n" x) p_list
  with _ -> failwith "Bad Points CSV"

(* -------------------------------------------------------------------------- *)
(* Distance Calculation and Display Logic *)
(* -------------------------------------------------------------------------- *)

(** [dummy_pt dim] is a dummy point created by the user or a default dummy point
    if the user does not provide one. *)
let dummy_pt dim =
  let err_msg = clr_ Reg Red "Invalid Input." in
  Printf.printf
    "\n\
     Now you will specify a point to calculate distances from each point in \
     your CSV file.\n\n";
  let prompt_coordinate name =
    let prompt =
      clr_ Und Ylw "Please specify the %s coordinate as a number:" name
    in
    Printf.printf "%s " prompt;
    let input = read_line () in
    Printf.printf "\n";
    match input with
    | input -> (
        try float_of_string input
        with Failure _ ->
          Printf.printf "%s Defaulting %s coordinate to 1.0\n\n" err_msg name;
          1.0)
    | exception End_of_file ->
        Printf.printf "%s Defaulting %s coordinate to 1.0\n" err_msg name;
        1.0
  in
  let coords =
    List.init dim (fun i -> prompt_coordinate ("X" ^ string_of_int (i + 1)))
  in
  create dim coords

(** [prompt_for_distfn ()] is the distance function the user chooses. *)
let prompt_for_distfn () =
  let prompt_metric =
    clr_ Reg Ylw
      "What distance metric would you like to use ([E: Euclidean] or [M: \
       Manhattan]): "
  in
  Printf.printf "%s" prompt_metric;
  let dist_metric = String.lowercase_ascii (read_line ()) in
  let distance_metric =
    if dist_metric = "e" then "euclidean"
    else if dist_metric = "m" then "manhattan"
    else "invalid"
  in
  distance_metric

(** [distances p dim dist_metric] is the list of tuples with distance(s)
    calculated under [dist_metric] between the points [p] in csv and a dummy
    point. *)
let distances p dim dist_metric =
  let p_list = read_points dim p in
  let dp = dummy_pt dim in
  List.map
    (fun p ->
      let distance =
        match dist_metric with
        | "euclidean" -> euclidean_distance p dp
        | "manhattan" -> manhattan_distance p dp
        | _ -> failwith "Invalid distance metric"
      in
      (to_string p, to_string dp, distance))
    p_list

(** [save_dists_to_csv distances metric choice] saves the distance information
    calculated under [metric] in the format of the user's [choice]. *)
let save_dists_to_csv distances metric choice =
  let file_name = Printf.sprintf "./data/distance_btw_points_%s.csv" metric in
  let csv_data =
    match choice with
    | "1" ->
        List.map
          (fun (p1, p2, dist) ->
            Printf.sprintf "The %s distance between %s and %s is: %f" metric p1
              p2 dist)
          distances
    | "2" ->
        List.map
          (fun (p1, p2, dist) -> Printf.sprintf "%s, %s, %f" p1 p2 dist)
          distances
    | _ ->
        Printf.printf "%s\n"
          (clr_ Bold Red "\nInvalid format selection. Not saving file.");
        []
  in
  if csv_data <> [] then (
    let oc = open_out file_name in
    List.iter (fun line -> Printf.fprintf oc "%s\n" line) csv_data;
    close_out oc;
    Printf.printf "\nData saved to %s\n" (clr_ Reg Grn "%s" file_name))

(** [ask_to_save_dists distances metric] prompts the user to choose whether or
    not to save the data they retrieved from the command dists. *)
let ask_to_save_dists distances metric =
  let msg =
    clr_ Bold Ylw
      "\nDo you want to save these distances to a CSV file? (yes/no): "
  in
  let choose_ = clr_ Und Ylw "\nChoose the format:\n\n" in
  let options =
    clr_ Reg Wht
      "1 - The [%s] distance between (p1, ..., pk) and (s1, ..., sj) is \
       [distance]\n\n\
       2 - (p1, ..., pk), (s1, ..., sj), distance\n\n"
      metric
  in
  let prompt = clr_ Und Ylw "Enter 1 or 2:" in
  Printf.printf "%s" msg;
  let input = String.lowercase_ascii (read_line ()) in
  match input with
  | "yes" ->
      Printf.printf "%s%s%s " choose_ options prompt;
      let format_choice = read_line () in
      save_dists_to_csv distances metric format_choice
  | "no" | _ -> ()

(** [print_distance] prints the distance(s) between all of the points i in i = 1
    ... n and a dummy point based on a distance metric the user chooses, as well
    as prompts the user to save the data in the data directory. *)
let print_distances points dim =
  let distance_metric = prompt_for_distfn () in
  match distance_metric with
  | "euclidean" | "manhattan" -> begin
      let distance_results = distances points dim distance_metric in
      let prompt_display =
        clr_ Bold Ylw "Would you like to see the distances? (yes/no): "
      in
      Printf.printf "%s" prompt_display;
      let input = String.lowercase_ascii (read_line ()) in
      if input = "yes" then
        List.iter
          (fun (p1, p2, dist) ->
            Printf.printf "The %s distance between %s and %s is: %5.2f\n"
              distance_metric p1 p2 dist)
          distance_results;
      ask_to_save_dists distance_results distance_metric
    end
  | _ ->
      Printf.printf "%s"
        (clr_ Bold Red "The metric you have provided is invalid. Try again.\n")

(* -------------------------------------------------------------------------- *)
(* Classifications UI Logic *)
(* -------------------------------------------------------------------------- *)
(* -------------------------------------------------------------------------- *)
(* KNN Display Logic *)
(* -------------------------------------------------------------------------- *)

(** [prompt_for_point dim] is the point the user wants to classify into a
    cluster using knn after running kmeans. *)
let prompt_for_point dim =
  let prompt =
    clr_ Und Wht
      "Enter the %dD coordinate you'd like to classify \
       (comma-separated-values; i.e. x1, ..., xk):"
      dim
  in
  let err_msg = clr_ Reg Red "Invalid input." in
  Printf.printf "\n%s " prompt;
  try
    let point =
      String.split_on_char ',' (read_line ()) |> List.map float_of_string
    in
    create dim point
  with _ ->
    Printf.printf "%s Defaulting to (1.0, ..., 1.0).\n" err_msg;
    create dim (List.init dim (fun _ -> 1.0))

(** [prompt_for_k_knn k_max] is the k-value from 1 to [k_max] that represents
    how many nearest neighbors will be considered in running knn. *)
let prompt_for_k_knn k_max =
  let prompt =
    clr_ Und Wht "Enter k, the number of neighbors to consider (1-%d):" k_max
  in
  let err_msg = clr_ Reg Red "Invalid input." in
  Printf.printf "\n%s " prompt;
  try
    let k_val = int_of_string (read_line ()) in
    k_val
  with _ ->
    Printf.printf "%s Defaulting to k = 1.\n" err_msg;
    1

(** [run_knn_ui clusters dim dist_fn] takes in user input for what point must be
    classified and runs knn to classify the point and inform the user of the
    conclusion, given the user provides valid data, otherwise default values
    shall be used. *)
let run_knn_ui clusters dim dist_fn =
  let point = prompt_for_point dim in
  let k = prompt_for_k_knn (List.length clusters) in
  let labeled_clusters =
    List.mapi (fun i cluster -> (cluster, string_of_int i)) clusters
  in
  let classification = classify k point labeled_clusters in
  let cluster_index = int_of_string classification + 1 in
  let class_msg =
    clr_ Reg Grn "The point %s belongs to Cluster %d.\n" (to_string point)
      cluster_index
  in
  if cluster_index >= 0 then Printf.printf "\n%s" class_msg
  else Printf.printf "\nERROR: Could not classify point.\n"

(* -------------------------------------------------------------------------- *)
(* Kmeans Display Logic *)
(* -------------------------------------------------------------------------- *)

(** [prompt_for_k point_ct] is the k value to use for running kmeans. *)
let prompt_for_k point_ct =
  let one_cluster_msg =
    clr_ Reg Grn
      "Your data only contains one point, so it will be clustered into one \
       cluster."
  in
  if point_ct = 1 then begin
    Printf.printf "%s" one_cluster_msg;
    1
  end
  else begin
    let inform_msg =
      clr_ Reg Wht
        "\n\
         Now you will specify a value for k, the number of clusters. Your file \
         contains %d points, so k must be between 1 and %d, inclusive.\n\n"
        point_ct point_ct
    in
    let prompt_msg = clr_ Und Ylw "Enter a k value for clustering:" in
    let err_msg = clr_ Reg Red "Invalid input." in
    Printf.printf "%s" inform_msg;
    Printf.printf "%s " prompt_msg;
    let input = read_line () in
    try
      begin
        let k = int_of_string input in
        if k > point_ct then failwith "Bad k value"
        else
          let success_msg =
            clr_ Reg Grn
              "\nGreat! Your data will be clustered into %d clusters.\n" k
          in
          Printf.printf "%s\n" success_msg;
          k
      end
    with Failure _ ->
      Printf.printf "%s Defaulting to k = 2\n\n" err_msg;
      2
  end

(** [pts_in_cluster cluster clusters points dist_fn] is the filtered [points]
    list containing points closer to [cluster] than to any other cluster in
    [clusters], as determined by [dist_fn]. *)
let pts_in_cluster cluster clusters points dist_fn =
  List.filter
    (fun point ->
      List.for_all
        (fun other_cluster ->
          dist_fn point cluster <= dist_fn point other_cluster)
        clusters)
    points

(** [display_clusters clusters points dist_fn] displays the [points] in
    [clusters]. *)
let display_clusters clusters points dist_fn =
  List.iteri
    (fun cluster_ind cluster ->
      Printf.printf "\nCluster %d:\n" (cluster_ind + 1);
      let cluster_points = pts_in_cluster cluster clusters points dist_fn in
      List.iter
        (fun point -> Printf.printf "- %s\n" (to_string point))
        cluster_points)
    clusters

(** [prompt_to_show_clusters clusters points dist_fn] asks the user if they want
    to see their clustered data. *)
let prompt_to_show_clusters clusters points dist_fn =
  let prompt_msg =
    clr_ Bold Ylw "\nWould you like to see the clustered data? (yes/no): "
  in
  Printf.printf "%s" prompt_msg;
  let input = String.lowercase_ascii (read_line ()) in
  if input = "yes" then display_clusters clusters points dist_fn else ()

(** [save_clusters_to_csv clusters points dist_fn k] saves cluster data to a csv
    file in the data directory. *)
let save_clusters_to_csv clusters points dist_fn k =
  let file_name = Printf.sprintf "./data/clusters_k%d.csv" k in
  let clr_file_name = clr_ Reg Grn "%s" file_name in
  let oc = open_out file_name in

  Printf.fprintf oc "Cluster,Point\n";
  List.iteri
    (fun cluster_index cluster ->
      let cluster_points = pts_in_cluster cluster clusters points dist_fn in
      List.iter
        (fun point ->
          Printf.fprintf oc "%d,%s\n" (cluster_index + 1) (to_string point))
        cluster_points)
    clusters;

  close_out oc;
  Printf.printf "Data saved to %s\n" clr_file_name

(** [ask_to_save_clusters clusters points dist_fn k] asks the user if they want
    to save their cluster data, and does so if they answer yes. *)
let ask_to_save_clusters clusters points dist_fn k =
  let prompt_msg =
    clr_ Bold Ylw
      "\nDo you want to save the cluster data to a CSV file? (yes/no): "
  in
  Printf.printf "%s" prompt_msg;
  let input = String.lowercase_ascii (read_line ()) in
  if input = "yes" then save_clusters_to_csv clusters points dist_fn k else ()

(** [prompt_to_classify clusters dim dist_fn] asks the user whether or not
    they'd like to classify a point using knn into a cluster resultant from
    running kmeans. *)
let prompt_to_classify clusters dim dist_fn =
  let prompt =
    clr_ Bold Ylw
      "\n\
       Would you like to classify a point into one of the clusters using kNN? \
       (yes/no): "
  in
  Printf.printf "%s" prompt;
  let classify_input = String.lowercase_ascii (read_line ()) in
  if classify_input = "yes" then run_knn_ui clusters dim dist_fn

(** [run_kmeans_ui csv dim point_count] performs k-means clustering on the
    dataset in [csv] and handles user interaction with processing and saving the
    data. *)
let run_kmeans_ui csv dim point_count =
  let points = read_points dim csv in
  let dist_fn =
    let err_msg = clr_ Reg Red "Invalid metric." in
    match prompt_for_distfn () with
    | "euclidean" -> euclidean_distance
    | "manhattan" -> manhattan_distance
    | _ ->
        Printf.printf "%s Defaulting to euclidean distance function.\n" err_msg;
        euclidean_distance
  in
  let k = prompt_for_k point_count in
  let progress_msg = Printf.sprintf "Running k-means with k = %d" k in
  show_progress_bar progress_msg;
  try
    let complete_msg = clr_ Und Ylw "Cluster centers:" in
    let clusters = run_custom_kmeans k points dist_fn in
    Printf.printf "%s\n" complete_msg;

    List.iteri
      (fun i cluster ->
        Printf.printf "Cluster %d : %s\n" (i + 1) (to_string cluster))
      clusters;

    prompt_to_show_clusters clusters points dist_fn;
    ask_to_save_clusters clusters points dist_fn k;
    prompt_to_classify clusters dim dist_fn
  with _ ->
    Printf.printf "%s unable to cluster [%s]\n" (clr_ Bold Red "Error:") csv

(* -------------------------------------------------------------------------- *)
(* Input Handlers *)
(* -------------------------------------------------------------------------- *)

(** [prompt_for_csv_file ()] is the csv file the user provided if provided with
    points in a valid format, otherwise they are assigned a random csv file with
    points. *)
let prompt_for_csv_file () =
  let prompt_msg =
    clr_ Reg Cyan
      "\n\
       Please provide the path to your CSV file (or press Enter to use the \
       default file): "
  in
  let no_file_msg = clr_ Reg Ylw "No file provided. " in
  Printf.printf "%s%!" prompt_msg;
  match read_line () with
  | "" -> begin
      Random.self_init ();
      let rand_index = Random.int 3 + 1 in
      let default_file =
        match rand_index with
        | 1 -> "./data/test_data.csv"
        | 2 -> "./data/test_data_2d.csv"
        | _ -> "./data/test_data_3d.csv"
      in
      Printf.printf "%sUsing default file: %s\n\n" no_file_msg default_file;
      default_file
    end
  | file ->
      if is_csv file then begin
        Printf.printf "\n";
        show_progress_bar "Loading csv";
        file
      end
      else (
        Printf.printf "Invalid file type. Defaulting to the default file.\n";
        "./data/test_data_2d.csv")

(** [attain_dimension csv] is the tuple containing the tuple with [csv] and its
    corresponding dimension. Informs the user of the dimension of the points in
    [csv]. *)
let rec attain_dimension () =
  let csv = prompt_for_csv_file () in
  let clr_csv = clr_ Reg Grn "%s" csv in
  let inform_msg_p1 = clr_ Reg Cyan "The points in" in
  let inform_msg_p2 = clr_ Reg Cyan "have the following dimension: " in
  let inform_msg =
    Printf.sprintf "%s [%s] %s" inform_msg_p1 clr_csv inform_msg_p2
  in
  let err_msg =
    clr_ Bold Red
      "Failed to determine a valid dimension from [%s]. Please check the CSV \
       format and upload again."
      csv
  in
  match get_dimension_from_csv csv with
  | Some (dim, point_count) ->
      Printf.printf "%s%d\n" inform_msg dim;
      (csv, dim, point_count)
  | None ->
      Printf.printf "%s\n" err_msg;
      attain_dimension ()

(* -------------------------------------------------------------------------- *)
(* Execution Logic *)
(* -------------------------------------------------------------------------- *)

(** [command_handler csv dim] is the handler of the program based on the user's
    input. *)
let rec command_handler csv dim point_count =
  let ty_msg = clr_ Bold Magenta "Thank you for choosing CamelClass !!" in
  Printf.printf "%s" (clr_ Bold Cyan "\nEnter a command ('help' for options): ");
  match String.lowercase_ascii (read_line ()) with
  | "points" ->
      print_points csv dim;
      command_handler csv dim point_count
  | "dists" ->
      print_distances csv dim;
      command_handler csv dim point_count
  | "kmeans" ->
      run_kmeans_ui csv dim point_count;
      command_handler csv dim point_count
  | "reload" ->
      let (new_csv : string), (new_dimension : int), (new_point_count : int) =
        attain_dimension ()
      in
      command_handler new_csv new_dimension new_point_count
  | "help" ->
      print_help ();
      command_handler csv dim point_count
  | "exit" ->
      Printf.printf "\n%s\n\n%s" ty_msg
        (clr_ Bold Grn "Exiting program. Goodbye!\n")
  | _ ->
      Printf.printf "%s" (clr_ Bold Red "Invalid command. Try again.\n");
      command_handler csv dim point_count

(** [run_io_mode ()] deals with program logic. *)
let run_io_mode () =
  let welcome_to_io_msg =
    clr_ Reg Grn "\nYou are now in CamelClass I/O mode !!"
  in
  Printf.printf "%s\n" welcome_to_io_msg;
  let csv_file, dimension, point_count = attain_dimension () in
  command_handler csv_file dimension point_count

(** Main Function *)
let () =
  let len = Array.length Sys.argv in
  let title = clr_ Bold Ylw "CamelClass: Classifications Demystified" in
  let debrief =
    "is a classification tool designed to simplify working with datasets in \
     OCaml."
  in
  let authors_title =
    clr_ Und Grn "By: Keti S., Neha N., Ruby P.G, Samantha V., Varvara B."
  in
  let error_msg =
    clr_ Reg Red
      "Error: You have provided too many arguments. Try running something \
       like: "
  in
  let err_bad_csv_msg =
    clr_ Reg Red
      "Error: The CSV you've provided is in an invalid format. Please rerun \
       the program once you're file is in a valid format."
  in
  let usage_msg = clr_ Reg Grn "$ dune exec bin/main.exe\n" in
  let invld_choice_msg = clr_ Reg Ylw "Invalid Input. " in
  try
    if len > 1 then Printf.printf "%s\n%s" error_msg usage_msg
    else begin
      Printf.printf "%s\n" welcome_ascii;
      Printf.printf "%s\n\n" authors_title;
      Printf.printf "%s %s\n\n" title debrief;
      Printf.printf "%s"
        (clr_ Reg Cyan
           "Would you like to use [GUI] or [I/O] mode?\n\
            NOTE: If selecting [GUI] mode, it will open a new window in your \
            desktop. ");
      let input = String.lowercase_ascii (read_line ()) in
      match input with
      | "gui" -> initialize_gui ()
      | "i/o" | "io" -> run_io_mode ()
      | _ ->
          Printf.printf "%sDefaulting to I/O mode.\n\n" invld_choice_msg;
          run_io_mode ()
    end
  with
  | Sys_error _ ->
      Printf.printf "%s"
        (clr_ Bold Red
           "That was incorrect/invalid input. Please rerun the program and \
            provide valid prompts.")
  | Failure e ->
      if e = "Bad Points CSV" then Printf.printf "\n%s" err_bad_csv_msg
      else failwith e
