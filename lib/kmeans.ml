open Point

let check_same_dimension points =
  match points with
  | [] -> true (* empty list is considered valid *)
  | first :: rest ->
      let dim = List.length (get_coordinates first) in
      List.for_all (fun p -> List.length (get_coordinates p) = dim) rest

let initialize_clusters k points =
  if not (check_same_dimension points) then
    invalid_arg "All points must have the same dimension";
  Random.self_init ();
  let n = List.length points in
  let rec pick_random_points k selected_points =
    if k = 0 then selected_points
    else
      let rand_index = Random.int n in
      let point = List.nth points rand_index in
      if List.mem point selected_points then
        pick_random_points k selected_points
      else pick_random_points (k - 1) (point :: selected_points)
  in
  pick_random_points k []

let assign_points points clusters =
  if not (check_same_dimension points) then
    invalid_arg "All points must have the same dimension";
  List.map
    (fun c ->
      let assigned_points =
        List.filter
          (fun p ->
            List.for_all
              (fun other_c ->
                euclidean_distance p c <= euclidean_distance p other_c)
              clusters)
          points
      in
      (c, assigned_points))
    clusters

let update_centroids assignments =
  List.map
    (fun (cluster, points) ->
      if points = [] then cluster
      else if not (check_same_dimension (cluster :: points)) then
        invalid_arg "All points in cluster must have the same dimension"
      else
        let coord_lists = List.map get_coordinates points in
        let coord_sums =
          List.fold_left (List.map2 ( +. )) (List.hd coord_lists)
            (List.tl coord_lists)
        in
        let mean_coords =
          List.map (fun s -> s /. float_of_int (List.length points)) coord_sums
        in
        create (List.length mean_coords) mean_coords)
    assignments

let has_converged old_clusters new_clusters threshold =
  List.for_all2
    (fun old_c new_c -> euclidean_distance old_c new_c < threshold)
    old_clusters new_clusters
