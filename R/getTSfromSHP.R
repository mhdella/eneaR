#' Aggregated a gridded object into national or regional boundaries. 
#' @author Matteo De Felice
getTSfromSHP <- function(obj, lat = NA, lon = NA, ADM = 2, type = 'mean', weighted = TRUE) {
    if (ADM == 2) {
        eumap = readOGR(system.file("NUTS", package = "eneaR"), "NUTS_REG_01M_2013_REGIONS")
    } else if (ADM == 1) {
        eumap = readOGR(system.file("NUTS", package = "eneaR"), "NUTS_REG_01M_2013_ADM1")
    } else if (ADM == 0){
        eumap = readOGR(system.file("NUTS", package = "eneaR"), "countries_EU")
        names(eumap)[1] = "NUTS_ID"
    } else {
        eumap = readOGR(system.file("NUTS", package = "eneaR"), "borders-wgs84")
    }
    # Select type of arithmetic function
    if (type == 'mean') {
        base_fun = mean
        array_fun = rowMeans
    } else if (type == 'sum') {
        base_fun = sum
        array_fun = rowSums
    } 
    if (!is.list(obj)) {
        if (is.na(lat) || is.na(lon)) {
            stop("You need to specify lat and lon vector in case of not-ECOMS objects")
        }
        pts = expand.grid(lat = lat, lon = lon)
        pts_index = expand.grid(lat = seq(1, length(lat)), lon = seq(1, length(lon)))
    } else {
        pts = expand.grid(lat = obj$xyCoords$y, lon = obj$xyCoords$x)
        pts_index = expand.grid(lat = seq(1, length(obj$xyCoords$y)), lon = seq(1, length(obj$xyCoords$x)))
        lat = obj$xyCoords$y
        lon = obj$xyCoords$x
        obj = obj$Data
    }

    coordinates(pts) = c("lon", "lat")
    proj4string(pts) = proj4string(eumap)
    
    over_target = over(pts, as(eumap, "SpatialPolygons"))
    pts$region = eumap$NUTS_ID[over_target]

    pts_index$region = droplevels(eumap$NUTS_ID[over_target])
    pts_index = pts_index[!is.na(over_target), ]

    SEL_REGIONS = levels(pts_index$region)
    data = list()
    for (REG in SEL_REGIONS) {
        sel_pts = pts_index[pts_index$region == REG, c(1, 2)]
        lsel = vector("list", nrow(sel_pts))
        weight_lat = 0
        for (i in 1:nrow(sel_pts)) {
            if (length(dim(obj)) == 2) {
                ## 2D array
                lsel[[i]] = obj[sel_pts$lat[i], sel_pts$lon[i]]
            } else if (length(dim(obj)) == 3) {
                ## 3D array
                lsel[[i]] = obj[, sel_pts$lat[i], sel_pts$lon[i]]
            } else {
                ## 4D array
                lsel[[i]] = t(obj[, , sel_pts$lat[i], sel_pts$lon[i]]) 
            }
            if (weighted) {
                # Weight by cos(lat)
                lsel[[i]] = lsel[[i]] * cos(sel_pts$lat[i] * pi / 180)
                weight_lat =  weight_lat + cos(sel_pts$lat[i] * pi / 180)
            }
        }
        lsel = do.call("cbind", lsel)
        if ((type != 'sum') && (type != 'mean')) {
            # In case of != sum or mean
            # we assume the output is "just" the raw 
            # cbind of selected points
            d = lsel
        } else {
            if (length(dim(obj)) == 2) {
                d = base_fun(lsel, na.rm = T)
            } else if (length(dim(obj)) == 3) {
                d = array_fun(lsel, na.rm = T)
            } else {
                nmem = dim(obj)[1]
                d = matrix(NA, nrow = nrow(lsel), ncol = nmem)
                for (k in 1:nmem) {
                    d[, k] = array_fun(matrix(lsel[, seq(k, ncol(lsel), nmem)], nr = nrow(lsel)), na.rm = T)
                }
            }
            # Weighted part
            if (weighted && type == 'mean') {
                d = d * nrow(sel_pts) / weight_lat
            }
        }
        data[[REG]] = d
    }
    return(data)
}
