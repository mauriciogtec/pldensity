# test data (True gaussian mixture)
library(pldensity)
library(plotly)
library(mvtnorm)

# set.seed(110104)
nclust <- 4
d <- 2
mu <- list(c(.75, .5), c(.5, .75), c(.25, .5), c(.75, .3))
S <- list(matrix(.1^2 * c(1, .5, .5, 1), 2, 2), .05^2 * diag(2),
          matrix(.1^2 * c(1, -.5, -.5, 1), 2, 2), .075^2 * diag(2))
n <- 1000
k <- sample(1:4, n, TRUE)
y <- matrix(0, n, d)
for (i in 1:nclust) {
  idx <- (k == i)
  print(mu[[i]])
  y[idx, ] <- rmvnorm(sum(idx), mu[[i]], S[[i]])
}
summary(y)
plot(y, xlim = c(0, 1), ylim = c(0, 1), bg = k, pch = 21,
     main = "Simulated normal mixture data")

system.time({
  res2 <- dp_normal_mix(
    y[ , ], 
    N = 100,
    alpha = 1, 
    lambda = runif(2), 
    kappa = .1, 
    nu = 2,
    Omega = .08 ^ 2 * diag(2))  
})

resol <- 50
xseq <- seq(0, 1, length.out = resol)
yseq <- seq(0, 1, length.out = resol)
mesh <- data.matrix(expand.grid(xseq, yseq))

system.time({
  z <- dp_normal_deval(res2, mesh, nparticles = 100)  
})


z <- matrix(z, resol, resol)
contour(z, add = TRUE, nlevels = 40)
plot_ly(z = ~t(z)) %>% add_heatmap()

zcond <- dp_normal_deval_conditional(res2, matrix(xseq, ncol = 1), 1, 2, matrix(0.5, 1, 1), 5)
plot(xseq, zcond, type = "l", main = "Prox(lon | lat = 0.5)")
integrate(function(x) dp_normal_deval_conditional(res2, matrix(x, ncol = 1), 1, 2, matrix(0.5, 1, 1), 5), 0, 1)


res3 <- dp_normal_marginal(res2, 1)
mesh <- data.frame(x = seq(0, 1, length.out = resol))
z <- dp_normal_deval(res3, data.matrix(mesh), nparticles = 30)
plot(mesh$x, z, type = "l")
integrate(function(x) sapply(x, function(s) dp_normal_deval(matrix(s, 1, 1), res3, nparticles = 30)), -5, 5)

# 0. Libraries ===================================
library(tidyverse)
# library(lubridate)
library(leaflet)
library(sp)
library(pldensity)

# 1. Read Data =====================================
rides <- read_csv("D:/Datasets/Rides_A.csv")
rides <- rides %>%
  mutate(datehour = lubridate::ymd_h(
    paste(paste(
      lubridate::year(started_on), 
      lubridate::month(started_on), 
      lubridate::day(started_on), sep = "-"), 
      lubridate::hour(started_on))))

rides_count <- rides %>%
  group_by(datehour) %>%
  count()

plot(tail(rides_count$datehour, 100), tail(rides_count$n, 100), type = "l")
abline(h = mean(rides_count$n), col = "red")


example <- rides %>%
  filter(datehour == lubridate::ymd_h("2017-04-07 23"))

x <- example %>%
  select(start_location_lat, start_location_long) %>%
  rename(lat = start_location_lat, lon = start_location_long)

# x$lat <- 0.1 + 0.8 * (x$lat - min(x$lat)) / (max(x$lat) - min(x$lat))
# x$lon <- 0.1 + 0.8 * (x$lon - min(x$lon)) / (max(x$lon) - min(x$lon))
# x$lat2 <- 0.1 + 0.8 * (x$lat2 - min(x$lat2)) / (max(x$lat2) - min(x$lat2))
# x$lon2 <- 0.1 + 0.8 * (x$lon2 - min(x$lon2)) / (max(x$lon2) - min(x$lon2))
# x$total_fare <- 0.1 + 0.8 * (x$total_fare - min(x$total_fare)) / (max(x$total_fare) - min(x$total_fare))

plot(x, main = "Ride Austin Trips")
plot(x[ ,c(1,2)], main = "Ride Austin Trips")

x <- data.matrix(x)

system.time({
  res2 <- dp_normal_mix(
    x[ , ],
    N = 1000,
    alpha = 15,
    lambda = c(30.302445, -97.731970),
    kappa = .1,
    nu = 2,
    Omega =  0.002 ^ 2 * diag(2))
})

z <-  dp_normal_deval(res2, x, nparticles = 100)

xsp <- SpatialPointsDataFrame(
  coords = x[ ,2:1], 
  data = data.frame(density = z)
)

# Eval density
resol <- 100
xseq <- seq(30.13, 30.52, length.out = resol)
yseq <-  seq(-98.014, -97.58, length.out = resol)
mesh <- data.matrix(expand.grid(xseq, yseq, length.out = resol))
z <- dp_normal_deval(res2, mesh[ ,c(1,2)], nparticles = 30)
z <- matrix(z, resol, resol)
cl <- contourLines(xseq, yseq, z, nlevels = 250)

pal <- colorNumeric("Spectral", domain = xsp@data$density)
leafletmap <- leaflet(xsp) %>% 
  addProviderTiles(providers$CartoDB.Positron)%>% 
  setView(lat = 30.302445, lng = -97.731970, zoom = 11) 

for (i in seq_along(cl)) {
  leafletmap <- leafletmap %>% addPolygons(
    lng = cl[[i]]$y, 
    lat = cl[[i]]$x, 
    fillColor = "red", 
    fillOpacity = .05,
    stroke = FALSE)  
}

leafletmap <- leafletmap %>%
  addCircleMarkers(
    radius = 3, 
    stroke = FALSE, 
    color = ~pal(density),
    fillOpacity = 0.8
  ) %>% 
  addLegend(
    "bottomright",
    values = ~density,
    pal = pal) 
leafletmap

plot(x)
contour(xseq, yseq, z, add = TRUE, nlevels = 1000)
plot_ly(y = ~xseq, x = ~yseq, z = ~z) %>% add_heatmap()

#### ORIGIN AND DESTINATION

x <- example %>%
  select(start_location_lat, start_location_long, end_location_lat, end_location_long) %>%
  # mutate(total_fare = scale(total_fare, TRUE, TRUE)) %>% 
  rename(lat = start_location_lat, lon = start_location_long, lat2 = end_location_lat, lon2 = end_location_long)
# 
plot(x, main = "Ride Austin Trips")
# plot(x[ ,c(1,2)], main = "Ride Austin Trips")

x <- data.matrix(x)

system.time({
  res2 <- dp_normal_mix(
    x[ , ],
    N = 100,
    alpha = 1,
    lambda = c(30.302445, -97.731970, 30.302445, -97.731970),
    kappa = .1,
    nu = 2,
    Omega = 0.005 ^ 2 * diag(4))
})

# 1.0 PLOT MAP OF DESTINATIONS

res_destination <- dp_normal_marginal(res2, 3:4)
z <-  dp_normal_deval(res_destination, x[ ,3:4], nparticles = 100)

xsp <- SpatialPointsDataFrame(
  coords = x[ ,4:3], 
  data = data.frame(density = z)
)

resol <- 100
xseq <- seq(30.13, 30.52, length.out = resol)
yseq <-  seq(-98.014, -97.58, length.out = resol)
mesh <- data.matrix(expand.grid(xseq, yseq, length.out = resol))
z <- dp_normal_deval(res_destination, mesh[ ,c(1,2)], nparticles = 30)
z <- matrix(z, resol, resol)
cl <- contourLines(xseq, yseq, z, nlevels = 250)

pal <- colorNumeric("Spectral", domain = xsp@data$density)
leafletmap <- leaflet(xsp) %>% 
  addProviderTiles(providers$CartoDB.Positron)%>% 
  setView(lat = 30.302445, lng = -97.731970, zoom = 11) 

for (i in seq_along(cl)) {
  leafletmap <- leafletmap %>% addPolygons(
    lng = cl[[i]]$y, 
    lat = cl[[i]]$x, 
    fillColor = "red", 
    fillOpacity = .05,
    stroke = FALSE)  
}

leafletmap <- leafletmap %>%
  addCircleMarkers(
    radius = 3, 
    stroke = FALSE, 
    color = ~pal(density),
    fillOpacity = 0.8
  ) %>% 
  addLegend(
    "bottomright",
    values = ~density,
    pal = pal) 
leafletmap



# 2.0 CONDITION ON TRIPS COMING FROM THE AIRPORT

# conddensity <- dp_normal_deval_conditional(res2, x[ ,3:4], 3:4, 1:2, 
#                                            matrix(c(30.2726, -97.667093), 1, 2), nparticles = 30)
xsp <- SpatialPointsDataFrame(
  coords = x[ ,4:3],
  data = data.frame(density = conddensity)
)

# Eval density
resol <- 50
xseq <- seq(30.1, 30.56, length.out = resol)
yseq <-  seq(-98.014, -97.58, length.out = resol)
mesh <- data.matrix(expand.grid(xseq, yseq, length.out = resol))
zcond <- dp_normal_deval_conditional(res2, mesh[ ,1:2], 3:4, 1:2, matrix(c(30.204509, -97.666676), 1, 2), nparticles = 10)
zcond <- matrix(zcond, resol, resol)
cl <- contourLines(xseq, yseq, zcond, nlevels = 250)

pal <- colorNumeric("Spectral", domain = xsp@data$density)
leafletmap <- leaflet(xsp) %>% 
  addProviderTiles(providers$CartoDB.Positron)%>% 
  setView(lat = 30.204509, lng = -97.666676, zoom = 11) 

for (i in seq_along(cl)) {
  leafletmap <- leafletmap %>%
    addPolygons(
      lng = cl[[i]]$y, 
      lat = cl[[i]]$x, 
      fillColor = "red", 
      fillOpacity = .02,
      stroke = FALSE
    )  
}

leafletmap <- leafletmap %>%
  addMarkers(lat =~ 30.204509, lng = ~-97.666676) 
leafletmap

plot(x)
contour(xseq, yseq, zcond, add = TRUE, nlevels = 1000)
plot_ly(y = ~xseq, x = ~yseq, z = ~zcond) %>% add_heatmap()
