plot_field_discrete = function(x, lon, lat, lonlim = c(-180, 180), latlim = c(-70, 70), labels = c(), breaks, cscale = "Spectral",
                               varname = "x", title = c(), mask = NULL, siglev = NULL, plot_only_sig = F, smooth = F, smooth_factor = 5,
                               smooth_theta = 0.5, lineWidth = 0.5, dotSize = 0.5, GRID_STEP = 10, FONT_SIZE = 18) {
  
  ## X must be lon [rows] x lat [columns]
  ## Load world border shapefile: high-res for 'small' fileds
  if (length(latlim) > 0 && length(lonlim) > 0 && (diff(lonlim) * diff(latlim)) < 2500) {
    load(system.file("borders", "TM_WORLD_BORDERS-0.3.shp.Rdata", package = "enear"))
  } else {
    load(system.file("borders", "TM_WORLD_BORDERS_SIMPL-0.3.shp.Rdata", package = "enear"))
  }
  ## Checking longitude range
  if (any(lon > 180)) {
    # convert lon from 0-360 to -180,180
    lon[lon > 180] = lon[lon > 180] - 360
    warning('Transforming longitude from 0,360 to -180,180')
  }
  
  if (is.array(x) && length(dim(x)) > 2) {
    stop("you cannot plot an array with more than two dimensions")
  }
  
  ####################### SMOOTHING PART #########################
  if (smooth && is.data.frame(x)) {
    warning("Smoothing procedure on data frames is not implemented")
    smooth = F
  }
  if (smooth) {
    library(fields)
    library(akima)
    
    z = image.smooth(x, theta = smooth_theta)  #theta is the bandwidth parameter
    z = interp.surface.grid(list(x = lon, y = lat, z = z$z), 
                             grid.list = list(x = seq(lonlim[1], lonlim[2], abs(mean(diff(lon)))/smooth_factor),
                                              y = seq(latlim[1], latlim[2], abs(mean(diff(lat)))/smooth_factor)))
    x = z$z
    lon = z$x
    lat = z$y
  }
  if (!is.data.frame(x)) {
    # Check dimensions
    if (dim(x)[1] != length(lon)) {
      if (dim(x)[2] == length(lon)) {
        warning("Latitude and longitude vectors look swapped, data field will be transposed")
        x = t(x)
      } else {
        stop("Dimensions of x are not consistent with the lat-lon vectors provided")
      }
    }
    # convert to data frame
    dd = melt(x)
    dd[, 1] = lon[dd[, 1]]
    dd[, 2] = lat[dd[, 2]]
  } else {
    if (ncol(x) != 3) {
      stop('The data frame should have three columns containing longitude, latitude and the data field')
    }
    dd = x
  }
  # Putting the right column names
  names(dd) = c("lon", "lat", "x")
  
  dd$orig_x = dd$x
  
  # Adding default labels
  if (length(labels) == 0) {
    labels = pretty_labels(breaks)
  }
  
  dd$x = cut(dd$x, breaks = c(-Inf, breaks, Inf), labels = labels)
  
  ### SUBSETTING DATA
  if (length(lonlim) > 0) {
    dd = subset(dd, lon >= lonlim[1] & lon <= lonlim[2])
    wmap = subset(wmap, long >= lonlim[1] & long <= lonlim[2])
  }
  if (length(latlim) > 0) {
    dd = subset(dd, lat >= latlim[1] & lat <= latlim[2])
    wmap = subset(wmap, lat >= latlim[1] & lat <= latlim[2])
  }
  
  
  ## SIG POINTS
  if (!is.null(mask)) {
    # Longitudes and Latitudes of dots
    mask = mask > siglev
    ij_dots = which(mask == FALSE, arr.ind = T)
    lon_dots_all = lon[ij_dots[, 2]]
    lat_dots_all = lat[ij_dots[, 1]]
    int_dots = 1
    
    lon_dots = lon_dots_all[seq(1, length(lon_dots_all), by = int_dots)]
    lat_dots = lat_dots_all[seq(1, length(lat_dots_all), by = int_dots)]
    
    ij_data <- data.frame(lon_dots, lat_dots)
    
    ## MERGE with DD
    names(ij_data) = c("lon", "lat")
    ij_data$sig = 1
    
    dd = left_join(dd, ij_data)
    
  }
  
  # NORMAL PLOT
  if (!plot_only_sig) {
    g = ggplot() + geom_raster(data = dd, aes(x = lon, y = lat, fill = x), alpha = 0.8)
    if (!is.null(mask)) {
      g = g + geom_point(data = ij_data, aes(lon_dots, lat_dots), size = dotSize, alpha = 0.75, stroke = 0,
                         shape = 16)  #this line is due to ggplot2.0.0
    }
  } else {
    g = ggplot() + geom_raster(data = filter(dd, sig == 1), aes(x = lon, y = lat, fill = x), alpha = 0.8)
  }
  
  g = g + geom_path(data = wmap, aes(x = long, y = lat, group = group), size = lineWidth)
  
  if (length(cscale) == 1) {
    cscale = brewer.pal(length(labels), cscale)
  } else {
    if (length(cscale) != length(labels)) {
      warning('The palette length is different from the number of breaks. A default palette will be used.')
      cscale = brewer.pal(length(labels), 'Spectral')
    }
  }
  g = g + scale_fill_manual(name = varname, values = cscale, drop = F)
  
  g = g + ggtitle(title)
  g = g + theme_bw()  #+ theme(, panel.grid.major = element_line(size=1))
  g = g + scale_x_continuous(expand = c(0, 0), breaks = seq(-180, 180, by = GRID_STEP), limits = lonlim)
  g = g + scale_y_continuous(expand = c(0, 0), breaks = seq(-180, 180, by = GRID_STEP), limits = latlim)
  g = g + theme(text = element_text(size = FONT_SIZE), panel.border = element_rect(colour = "black", size = 2,
                                                                                   fill = NA), panel.grid.major = element_line(colour = "black", size = 0.25))
  g = g + xlab("Longitude") + ylab("Latitude")
  return(g)
}