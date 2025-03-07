#' toolCubicFunctionAggregate
#' 
#' Estimates the function that represents the sum of cubic function inverses
#' (sum in the x-axis)
#' 
#' Use case: aggregate country cubic cost functions to a single function that
#' represents the entire region.
#' 
#' input: coefficients of the n-th country level cubic cost function. 
#' 
#' Description of the problem: the aggregation of functions that represent  unit
#' costs, or prices in the y-axis, and quantities in the x-axis require operations
#' with the inverse of the original functions.  As complex functions present 
#' analytically challenging inverse function derivations, we adopt a  sampling
#' method to derive the function that corresponds to the sum of cubic function 
#' inverses.     
#' 
#' Further extensions: the R function can be extended to support more complex curve
#' estimations (beyonf third degree), whenever the mathematical function have a well
#' defined inverse function in the selected boundaries.
#'  
#' @param x magclass object that should be aggregated or data frame with
#' coefficients as columns. 
#' @param rel relation matrix containing a region mapping.
#' A mapping object should contain 2 columns in which each element of x
#' is mapped to the category it should belong to after (dis-)aggregation
#' @param xLowerBound numeric. Lower bound for x sampling (default=0). 
#' @param xUpperBound numeric. Upper bound for x sampling (default=100).
#' @param returnMagpie boolean. if true, the function will return a single data table
#' with all the countries in MagPie format. returnChart and returnSample are set to
#' FALSE automatically if this option is active (default=TRUE).
#' @param returnCoeff boolean. Return estimated coefficients (default=TRUE).
#' @param returnChart boolean. Return chart (default=FALSE).
#' @param returnSample boolean. Return samples used on estimation (default=FALSE).
#' @param numberOfSamples numeric. NUmber of y-axis samples used on estimation 
#' (default=1e3).
#' @param unirootLowerBound numeric. Lower bound to search for inverse solution in the
#' initial bounds (default = -10).
#' @param unirootUpperBound numeric. Upper bound to search for inverse solution in the
#' initial bounds (default = 1e100).  
#' @param colourPallete vector. colour pallete to use on chart (default=FALSE).
#' @param label list. List of chart labels (default=list(x = "x", y = "y", legend =
#' "legend")).
#' @param steepCurve list. List with coefficients for a very "vertical" function for the case with all countries with upper bound zero in an specific region aggregation (default= empty list, list()).
#' 
#' @return return: returns a list of magpie objects containing the coefficients for the
#' aggregate function. If returnMagpie is FALSE, returns a list containing the 
#' coefficients for the aggregate function (returnCoeff=TRUE), charts (returnChart=FALSE)
#' and/or samples used in the estimation (returnSample=FALSE).
#' 
#' @author Renato Rodrigues
#' @export
#' @importFrom magclass is.magpie as.data.frame
#' @importFrom reshape2 acast
#' @importFrom stats reshape uniroot
#' @importFrom nnls nnls
#' @seealso \code{\link{toolCubicFunctionDisaggregate}}
#' @examples
#'
#' # Example
#' # data
#' EUR <- setNames(data.frame(30,50,0.123432,2),c("c1","c2","c3","c4"))
#' NEU <- setNames(data.frame(30,50,1.650330,2),c("c1","c2","c3","c4"))
#' df <- rbind(EUR,NEU)
#' row.names(df) <- c("EUR","NEU")
#' # maxExtraction (upper limit for function estimation)
#' maxExtraction <- 23
#' # output
#' output <- toolCubicFunctionAggregate(df,xUpperBound=maxExtraction,
#'  returnMagpie=FALSE,returnChart=TRUE,returnSample=TRUE,
#'  label=list(x="Cumulated Extraction", y="Cost", legend="Region Fuel Functions"))
#' output$coeff
#' output$chart


toolCubicFunctionAggregate <- function(x, rel=NULL, xLowerBound=0, xUpperBound=100, returnMagpie=TRUE, returnCoeff=TRUE, returnChart=FALSE, returnSample=FALSE, numberOfSamples=1e3, unirootLowerBound = -10,unirootUpperBound = 1e100, colourPallete=FALSE, label = list(x = "x", y = "y", legend = "legend"), steepCurve = list()){
  
  data <- x
  
  if(is.null(rel$RegionCode))  rel$RegionCode  <- rel$region
  if(is.null(rel$CountryCode)) rel$CountryCode <- rel$country
  

  if (!(length(steepCurve) == 0)){  #set steep curve if all countries within a region have zero upper bound
    for (region in unique(rel$RegionCode)){
      countries <- rel$CountryCode[rel$RegionCode== as.character(region)]
      if (all(xUpperBound[countries,,] == 0)){ # if all countries within the region do not have any extraction potential
        # set a very high cost curve
        count <- 0
        for (coeff in names(steepCurve)) {
          data[countries,,coeff] = steepCurve[[coeff]]*(length(countries)^count)
          count <- count+1
        }
      }
    }
  }
  
  
  ### Start of cubicFitAggregate function
  
  # function used to fit by sampling the sum of function inverses (sum in the x-axis)
  # input: data <- data table with coefficients of the functions to be aggregated. Format: one column for each coefficient
  cubicFitAggregate <- function(data, xLowerBound=0, xUpperBound=100, returnCoeff=TRUE, returnChart=FALSE, returnSample=FALSE, numberOfSamples=1e3, unirootLowerBound = -10,unirootUpperBound = 1e100, colourPallete=FALSE, label = list(x = "x", y = "y", legend = "legend")){
    
    if (nrow(data) == 1 || is.null(nrow(data))){ # no need to aggregate a single function
      # preparing results
      result <- list()
      if (returnChart == TRUE){
        thirdDegreeFunction <-  function(x) {
          return( data[1] + data[2]*x + data[3]*x^2 + data[4]*x^3 )
        }
        p <- ggplot2::ggplot(data = NULL)
        p <- p + ggplot2::xlim(xLowerBound, xUpperBound)
        p <- p + ggplot2::stat_function(fun = thirdDegreeFunction, size=1, ggplot2::aes(colour = "_aggregated function", linetype = "_aggregated function"), na.rm=TRUE)
        p <- p + ggplot2::scale_linetype_manual(values = c("solid"), guide = FALSE)
        p <- p + ggplot2::labs(colour = label$legend, x = label$x, y = label$y)
        result$chart <- p # return chart
      }
      if (returnCoeff == TRUE){ # return coeff of estimated function
        if(length(result) == 0) {
          result <- c(data[1],data[2],data[3],data[4])
        } else {
          result$coeff <- c(data[1],data[2],data[3],data[4])
        }
      }
      return(result)  
    } 
    
    #cubic function of each row to be aggregated (ex: fY[[rowName]](20))
    fY <- apply(data, 1, function(coef){ function(x){ as.numeric(coef[1]) + as.numeric(coef[2])*x + as.numeric(coef[3])*x^2 + as.numeric(coef[4])*x^3 } })
    
    #inverse function
    inverse = function (f, lower = unirootLowerBound, upper = unirootUpperBound) {
      function (y) { 
        result <- stats::uniroot((function (x) f(x) - y), lower = lower, upper = upper, extendInt = "yes")$root 
        #tryCatch(
        #  result <- uniroot((function (x) f(x) - y), lower = lower, upper = upper, extendInt = "yes",maxiter = 10000, trace =2)$root, 
        #  error = return(NA)
        #)
        return(result)
      }
    }
    fYInverse <- lapply(rownames(data), function(rowName){
      function(x, lower = unirootLowerBound, upper = unirootUpperBound){ 
        lis<-vector()
        for(i in x){
          lis<-append(lis,inverse(fY[[rowName]],lower,upper)(i))
        }
        return(lis)
      }
    })
    names(fYInverse) <- rownames(data)
    
    # Boundaries for which all functions should be defined
    maxXtolerance <- 1e-10
    minX <- xLowerBound
    if (length(xUpperBound) > 1){ # one bound for each row
      maxX <- sum(xUpperBound)
      if (maxX < maxXtolerance){ # all rows have corner solution values for bounds
        maxX <- 1
        maxY <- max(sapply(rownames(data),function(rowName) fY[[as.character(rowName)]](maxX) ) )
      } else { # consider only rows with non corner solutions
        maxY <- max(sapply(rownames(data),function(rowName) ifelse(xUpperBound[rowName] > maxXtolerance, fY[[as.character(rowName)]](xUpperBound[rowName]),0) ))
      }
      minY <- max(sapply(rownames(data),function(rowName) fY[[as.character(rowName)]](xLowerBound)))
    } else { # single bound for all rows
      maxX <- xUpperBound
      if (maxX < maxXtolerance){ # all rows have corner solution values for bounds
        maxX <- 1
        maxY <- max(sapply(rownames(data),function(rowName) fY[[as.character(rowName)]](maxX) ) )
      } else { # consider only rows with non corner solutions
        maxY <- max(sapply(rownames(data),function(rowName) { ifelse(xUpperBound > maxXtolerance, fY[[as.character(rowName)]](xUpperBound),0) } ))
      }
      minY <- max(sapply(rownames(data),function(rowName) fY[[as.character(rowName)]](xLowerBound)))
    }
    minY <- max(c(0,minY))
   
    # Sampling
    # sampling y
    samples <- data.frame(y = seq(from=minY, to=maxY, length.out = numberOfSamples))
    # sampling x per function
    for (rowName in rownames(data)){
        samples[,(paste0(rowName,".x"))] <- fYInverse[[rowName]](samples$y,minX,maxX)
    }
    
    # total x
    samples$x <-rowSums(samples[grep("x", names(samples))])
    samples[samples<0] <- 0 #make sure all samples are greater or equal to zero
    
    # estimating the new function
    #use nnls to force positive coefficients 
    df <- data.frame(1, samples$x, samples$x^2, samples$x^3)
    df <- as.matrix(df)
    newFunction <- nnls::nnls(df,samples$y)
    newFunctionCoeff <- newFunction$x
    
    # preparing results
    result <- list()
    if (returnSample == TRUE){
      result$sample <- samples # return samples table
    }
    if (returnChart == TRUE){
      thirdDegreeFunction <-  function(x) {
        return( newFunctionCoeff[1] + newFunctionCoeff[2]*x + newFunctionCoeff[3]*x^2 + newFunctionCoeff[4]*x^3 )
      }
      p <- ggplot2::ggplot(samples, ggplot2::aes(samples$x, samples$y, group = 1)) +
        ggplot2::coord_cartesian(ylim = c(0, max(samples$y)))
      p <- p + ggplot2::stat_function(fun=thirdDegreeFunction, size=1, ggplot2::aes(colour = "_aggregated function", linetype = "_aggregated function"), na.rm=TRUE)
      for (i in 1:(nrow(data))){
        p <- p + eval(parse(text = paste0("ggplot2::stat_function(fun=fY[[\"", as.character(rownames(data)[i]) , "\"]], ggplot2::aes(colour = \"", as.character(rownames(data)[i]) , "\" , linetype = \"" , as.character(rownames(data)[i]), "\"), na.rm=TRUE)"))) #hack to allow legend
      }
      if ( !(colourPallete[1] == FALSE) & (length(colourPallete) >= nrow(data))){
        p <- p + ggplot2::scale_colour_manual(label$legend, values = colourPallete)
      }
      p <- p + ggplot2::scale_linetype_manual(values = c("solid", rep.int("dashed", nrow(data))), guide = FALSE)
      
      p <- p + ggplot2::guides(colour = ggplot2::guide_legend(override.aes = list(linetype = c("solid", rep.int("dashed", nrow(data))))))
      
      p <- p + ggplot2::labs(colour = label$legend, x = label$x, y = label$y)
      
      result$chart <- p # return chart
    }
    if (returnCoeff == TRUE){ # return coeff of estimated function
      names(newFunctionCoeff) <- colnames(data)
      if(length(result) == 0) {
        result <- newFunctionCoeff 
      } else {
        result$coeff <- newFunctionCoeff 
      }
    }
    return(result)
  }
  
  ### End of cubicFitUpscale function
  
  # pre processing data formats and executing estimations
  
  if(is.magpie(data)){
    df <- as.data.frame(data)
    # splitting large dimensional magpie objects
    dataNames <- names(df[,grep("Data", names(df))]) # all data names
    dataNames <- dataNames[-length(dataNames)] # remove last element (coefficient labels)
    factorGroups <- interaction(df[,dataNames]) # all combinations of Data values
    groupsList <- split(df, with(df, factorGroups), drop = TRUE)
    #looping through all data sets and estimating the respective aggregated functions 
    output <- lapply(seq_along(groupsList),
                     function(i) {
                       # preparing data (row names equal to regions, one column for each coefficient)
                       currentDf <- groupsList[[i]]
                       currentDf <- currentDf[c(2,length(currentDf)-1,length(currentDf))] #region, coeff, value 
                       names(currentDf) <- c("Region","coeff","value")  
                       currentDf <- reshape2::acast(currentDf, Region ~ coeff, value.var = 'value')
                       # estimating aggregated function
                       if (is.null(rel)){ # single aggregated function
                         out <- cubicFitAggregate(currentDf, xLowerBound=xLowerBound, xUpperBound=xUpperBound, returnCoeff=returnCoeff, returnChart=returnChart, returnSample=returnSample, numberOfSamples=numberOfSamples, unirootLowerBound =unirootLowerBound,unirootUpperBound =unirootUpperBound, colourPallete=colourPallete, label = label)
                       } else { # looping through new regions and estimating the aggregated function
                         if (returnMagpie==TRUE){
                           returnCoeff=TRUE
                           returnChart=FALSE
                           returnSample=FALSE
                         }
                         from <- ifelse(dim(rel)[2]>2,2,1) # country
                         to <- ifelse(dim(rel)[2]>2,3,2) # region
                         out <- sapply(unique(rel[[to]]), function(region) {
                           currentFilteredDf <- currentDf[rel[from][rel[to]==as.character(region)],]
                           # upper bound
                           currentxUpperBound <- as.numeric(xUpperBound[rel[from][rel[to]==as.character(region)],,names(groupsList[i])])
                           names(currentxUpperBound) <- getRegions(xUpperBound[rel[from][rel[to]==as.character(region)],,names(groupsList[i])])
                           outRegion <- cubicFitAggregate(currentFilteredDf, xLowerBound=xLowerBound, xUpperBound=currentxUpperBound, returnCoeff=returnCoeff, returnChart=returnChart, returnSample=returnSample, numberOfSamples=numberOfSamples, unirootLowerBound =unirootLowerBound,unirootUpperBound =unirootUpperBound, colourPallete=colourPallete, label = label)
                           return(outRegion)
                         })
                         if (returnMagpie==TRUE){
                           colnames(out) <- unique(rel[[to]])
                           rownames(out) <- colnames(currentDf)
                           out <- as.magpie(out)
                         } else {
                           names(out) <- unique(rel[[to]])
                         }
                       }
                       return(out)
                     })
    names(output) <- names(groupsList)

    #from lists to dimension in the magpie names 
    outputList <- output
    output <- lapply(seq_along(outputList), function(i) {
      out <- add_dimension(outputList[[i]], dim = 3.1, nm = names(outputList)[i])
    })
    names(output) <- names(outputList) 
    # merge all magpie objects into a single one
    output <- mbind(output)

  } else {
    if (is.null(rel)){ # single aggregated function
      output <- cubicFitAggregate(data, xLowerBound=xLowerBound, xUpperBound=xUpperBound, returnCoeff=returnCoeff, returnChart=returnChart, returnSample=returnSample, numberOfSamples=numberOfSamples, unirootLowerBound =unirootLowerBound,unirootUpperBound =unirootUpperBound, colourPallete=colourPallete, label = label)
    } else { # looping through new regions and estimating the aggregated function
      if (returnMagpie==TRUE){
        returnCoeff=TRUE
        returnChart=FALSE
        returnSample=FALSE
      }
      from <- ifelse(dim(rel)[2]>2,2,1) # country
      to <- ifelse(dim(rel)[2]>2,3,2) # region
      output <- sapply(unique(rel[[to]]), function(region) {
        currentFilteredDf <- data[rel[from][rel[to]==as.character(region)],]
        currentxUpperBound <- as.numeric(xUpperBound[rel[from][rel[to]==as.character(region)],,])
        outRegion <- cubicFitAggregate(currentFilteredDf, xLowerBound=xLowerBound, xUpperBound=currentxUpperBound, returnCoeff=returnCoeff, returnChart=returnChart, returnSample=returnSample, numberOfSamples=numberOfSamples, unirootLowerBound =unirootLowerBound,unirootUpperBound =unirootUpperBound, colourPallete=colourPallete, label = label)
        return(outRegion)
      }) 
      if (returnMagpie==TRUE){
        colnames(output) <- unique(rel[[to]])
        rownames(output) <- colnames(data)
        output <- as.magpie(output)
      } else {
        names(out) <- unique(rel[[to]])
      }
    }
  }

  return(output)
}
