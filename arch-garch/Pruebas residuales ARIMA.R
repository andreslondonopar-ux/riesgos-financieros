tabla.Box.Pierce <- function(residuo, max.lag = 20, type = 'Box-Pierce'){
  ## Prueba de autocorrelacion de errores de un modelo
  ### Inputs:
  #### residuo: errores del modelo estimado
  #### max.lag: Numero maximo de rezagos a usar
  #### type: Tipo de prueba: "Box-Pierce", "Ljung-Box"
  ### Output:
  #### TABLABP: Tabla resumen de las pruebas
  
  BP.estadistico <- matrix(data = 0, nrow = max.lag, ncol = 1)
  BP.pval <- matrix(data = 0, nrow = max.lag, ncol = 1)
  
  for(i in 1:max.lag){
    BP <- Box.test(x = residuo, lag = i, type = type)
    BP.estadistico[i] <- round(x = BP[['statistic']], digits = 3)
    BP.pval[i] <- round(x = BP[['p.value']], digits = 5)
  }
  labels <- c('Rezagos', type, 'p-valor')
  Cuerpo.Tabla <- cbind(matrix(data = 1:max.lag, nrow = max.lag, ncol = 1), BP.estadistico, BP.pval)
  TABLABP <- data.frame(Cuerpo.Tabla)
  names(TABLABP) <- labels
  return(TABLABP)
}

tabla.ARCH.LM <- function(residuo, max.lag = 20){ 
  ## Prueba ARCH-LM para no homocedasticidad en errores de un modelo
  ### Inputs:
  #### residuo: residuos del modelo estimado a probar
  #### max.lag: maximo de residuos a probar
  ### Output:
  #### TABLA.ARCH: Tabla de resumen de las pruebas
  
  require(FinTS)
  
  ARCH.estadistico <- matrix(0,max.lag,1)
  ARCH.pval <-matrix(0,max.lag,1)
  
  # se calcula la prueba para los diferentes rezagos
  for (i in 1:max.lag) {
    archa<-ArchTest(residuo, lags=i)
    ARCH.estadistico[i]<-archa$statistic
    ARCH.pval[i]<-round(archa$p.value,5)
    
  }
  labels<- c( "Rezagos", "ARCH LM-EstadÌstico", "p-valor")
  
  Cuerpo.Tabla <- cbind(matrix(1:max.lag,max.lag,1), 
                        ARCH.estadistico, ARCH.pval)
  TABLA.ARCH <- data.frame(Cuerpo.Tabla)
  names(TABLA.ARCH) <- labels
  return(TABLA.ARCH)
}
