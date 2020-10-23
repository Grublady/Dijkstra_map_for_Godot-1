use super::*;

impl Default for DijkstraMap {
    fn default() -> Self {
        Self::new()
    }
}

impl DijkstraMap {
    /// The "constructor" of the class.
    pub fn new() -> Self {
        DijkstraMap {
            connections: FnvHashMap::default(),
            reverse_connections: FnvHashMap::default(),
            map: FnvHashMap::default(),
            sorted_points: Vec::<PointID>::new(),
            disabled_points: FnvHashSet::default(),
            terrain_map: FnvHashMap::default(),
        }
    }

    /// Clears the DijkstraMap.
    pub fn clear(&mut self) {
        self.connections.clear();
        self.reverse_connections.clear();
        self.map.clear();
        self.sorted_points.clear();
        self.disabled_points.clear();
        self.terrain_map.clear();
    }

    /// Adds new point with given ID and optional terrain ID into the graph.
    ///
    /// # Errors
    ///
    /// Returns `Err` if point with that ID already exists, without modifying the map.
    pub fn add_point(&mut self, id: PointID, terrain_type: TerrainType) -> Result<(), ()> {
        if self.has_point(id) {
            Err(())
        } else {
            self.connections.insert(id, FnvHashMap::default());
            self.reverse_connections.insert(id, FnvHashMap::default());
            self.terrain_map.insert(id, terrain_type);
            Ok(())
        }
    }

    /// Removes point from graph along with all of its connections.
    ///
    /// # Errors
    ///
    /// Returns `Err` if `point` doesn't exist in the map.
    pub fn remove_point(&mut self, point: PointID) -> Result<(), ()> {
        self.disabled_points.remove(&point);
        // remove this point's entry from connections
        match self.connections.remove(&point) {
            None => Err(()),
            Some(neighbours) => {
                // remove reverse connections to this point from neighbours
                for nbr in neighbours.keys() {
                    if let Some(connection) = self.reverse_connections.get_mut(nbr) {
                        connection.remove(&point);
                    }
                }
                // remove this points entry from reverse connections
                let nbrs2 = self.reverse_connections.remove(&point).unwrap();
                // remove connections to this point from reverse neighbours
                for nbr in nbrs2.keys() {
                    if let Some(connection) = self.connections.get_mut(nbr) {
                        connection.remove(&point);
                    }
                }
                Ok(())
            }
        }
    }

    /// Disables point from pathfinding.
    ///
    /// # Errors
    ///
    /// Returns `Err` if point doesn't exist.
    ///
    /// ## Note
    ///
    /// Points are enabled by default.
    pub fn disable_point(&mut self, point: PointID) -> Result<(), ()> {
        if self.connections.contains_key(&point) {
            self.disabled_points.insert(point);
            Ok(())
        } else {
            Err(())
        }
    }

    /// Enables point for pathfinding.
    ///
    /// # Errors
    ///
    /// Returns `Err` if point doesn't exist.
    ///
    /// ## Note
    ///
    /// Points are enabled by default.
    pub fn enable_point(&mut self, point: PointID) -> Result<(), ()> {
        if self.connections.contains_key(&point) {
            self.disabled_points.remove(&point);
            Ok(())
        } else {
            Err(())
        }
    }

    /// Adds connection with given cost (or cost of existing existing connection) between a source point and target point if they exist.
    ///
    /// # Parameters
    ///
    /// - `source` : source point of the connection.
    /// - `target` : target point of the connection.
    /// - `weight` (default : `1.0`) : weight of the connection.
    /// - `bidirectional` (default : `true`) : wether or not the reciprocal connection should be made.
    ///
    /// # Errors
    ///
    /// Returns `Err` if one of the point does not exist.
    pub fn connect_points(
        &mut self,
        source: PointID,
        target: PointID,
        weight: Option<Weight>,
        bidirectional: Option<bool>,
    ) -> Result<(), ()> {
        let weight = weight.unwrap_or(Weight(1.0));
        let bidirectional = bidirectional.unwrap_or(true);
        if bidirectional {
            self.connect_points(source, target, Some(weight), Some(false))
                .and(self.connect_points(target, source, Some(weight), Some(false)))
        } else {
            let connection = self.connections.get_mut(&source).ok_or(())?;
            let reverse_connection = self.reverse_connections.get_mut(&target).ok_or(())?;
            connection.insert(target, weight);
            reverse_connection.insert(source, weight);
            Ok(())
        }
    }

    /// Removes connection between source point and target point.
    ///
    /// # Parameters
    ///
    /// - `source` : source point of the connection.
    /// - `target` : target point of the connection.
    /// - `bidirectional` (default : `true`) : if `true`, also removes connection from target to source.
    ///
    /// # Errors
    ///
    /// Returns `Err` if one of the point does not exist.
    pub fn remove_connection(
        &mut self,
        source: PointID,
        target: PointID,
        bidirectional: Option<bool>,
    ) -> Result<(), ()> {
        let bidirectional = bidirectional.unwrap_or(true);
        if bidirectional {
            self.remove_connection(source, target, Some(false))
                .and(self.remove_connection(target, source, Some(false)))
        } else {
            let connection = self.connections.get_mut(&source).ok_or(())?;
            let reverse_connection = self.reverse_connections.get_mut(&source).ok_or(())?;
            connection.remove(&target);
            reverse_connection.remove(&source);
            Ok(())
        }
    }

    ///sets terrain ID for given point and returns OK. If point doesn't exist, returns FAILED
    pub fn set_terrain_for_point(
        &mut self,
        id: PointID,
        terrain_type: TerrainType,
    ) -> Result<(), ()> {
        if self.has_point(id) {
            self.terrain_map.insert(id, terrain_type);
            Ok(())
        } else {
            Err(())
        }
    }
}

#[cfg(test)]
mod test {
    use super::*;
    const ID0: PointID = PointID(0);
    const ID1: PointID = PointID(1);
    const ID2: PointID = PointID(2);
    const TERRAIN: TerrainType = TerrainType::DefaultTerrain;
    fn setup_add012() -> DijkstraMap {
        let mut djikstra = DijkstraMap::new();
        djikstra.add_point(ID0, TERRAIN).unwrap();
        djikstra.add_point(ID1, TERRAIN).unwrap();
        djikstra.add_point(ID2, TERRAIN).unwrap();
        djikstra
    }
    fn setup_add012_connect0to1and1to2and2to3() -> DijkstraMap {
        let mut d = setup_add012();
        d.connect_points(ID0, ID1, None, None).unwrap();
        d.connect_points(ID1, ID2, None, None).unwrap();
        d
    }
    #[test]
    fn setup1() {
        setup_add012();
    }
    #[test]
    fn setup2() {
        setup_add012_connect0to1and1to2and2to3();
    }
    #[test]
    fn connecting_bidirectionnal_works_one_way() {
        let mut d = setup_add012();
        d.connect_points(ID0, ID1, None, None).unwrap();
        assert!(d.has_connection(ID0, ID1));
    }
    #[test]
    fn connecting_bidirectionnal_works_reverse_way() {
        let mut d = setup_add012();
        d.connect_points(ID0, ID1, None, None).unwrap();
        assert!(d.has_connection(ID1, ID0));
    }
    #[test]
    fn connecting_unidirect_connect0to1() {
        let mut d = setup_add012();
        d.connect_points(ID0, ID1, None, Some(false)).unwrap();
        assert!(d.has_connection(ID0, ID1));
        assert!(!d.has_connection(ID1, ID0));
    }
    #[test]
    fn connecting_unidirect_dont_connect1to0() {
        let mut d = setup_add012();
        d.connect_points(ID0, ID1, None, Some(false)).unwrap();
        assert!(!d.has_connection(ID1, ID0));
    }
    #[test]
    fn add_point_works() {
        let _d = setup_add012();
    }
    #[test]
    #[should_panic]
    fn cant_uses_same_id_twice() {
        let mut d = setup_add012();
        println!("before panic");
        d.add_point(ID0, TERRAIN).unwrap();
    }
    #[test]
    fn remove_points_works() {
        let mut d = setup_add012();
        d.remove_point(ID0).expect("failed remove points");
        d.add_point(ID0, TERRAIN).expect("failed to read point");
    }
    #[test]
    fn disable_points_works() {
        let mut d = setup_add012();
        d.disable_point(ID0).unwrap();
        assert!(d.is_point_disabled(ID0));
        assert!(!d.is_point_disabled(ID1));
    }
    #[test]
    fn enable_point_works() {
        let mut d = setup_add012();
        assert!(!d.is_point_disabled(ID0));
        d.disable_point(ID0).unwrap();
        assert!(d.is_point_disabled(ID0));
        d.enable_point(ID0).unwrap();
        assert!(!d.is_point_disabled(ID0));
    }
    #[test]
    fn set_terrain4points_works() {
        let mut d = setup_add012();
        let terrain = d.get_terrain_for_point(ID0).unwrap();
        assert_eq!(*terrain, TerrainType::DefaultTerrain);
        d.set_terrain_for_point(ID0, TerrainType::Terrain(5))
            .unwrap();
        let terrain = d.get_terrain_for_point(ID0).unwrap();
        assert_eq!(*terrain, TerrainType::Terrain(5));
    }
}
