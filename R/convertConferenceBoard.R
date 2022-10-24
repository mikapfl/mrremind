#' convertConferenceBoard
#' @param x MAgPIE object to be converted
#' @author Aman Malik
#' @return A magpie object with country-level results

convertConferenceBoard <- function(x) {
  # x <- readSource("ConferenceBoard",convert = FALSE)
  # CHN1 is the China alternative and CHN2 is the China official numbers.
  # The former is based on alternative growth estimates, while the latter is based on official data
  # avg <- colMeans(x,dims = 1,na.rm = TRUE)
 # means <- colMeans(x,na.rm = TRUE)
 # means1 <- as.numeric(means["GLO","y2019","Output per person (without agriculture)"])
y <- toolCountryFill(x[, , "Output per person (without agriculture)"], fill = 58302) # all countries with no value get average labour productivity (without agriculture) of the world
 z <- toolCountryFill(x[, , "Output per Employed Person"], fill = 54114.77)
 a <- toolCountryFill(x[, , "Employment in agriculture"], fill = 0)
 x <- mbind(y, z, a)

 return (x)

}
