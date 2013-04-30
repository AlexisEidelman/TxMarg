### import des sorties de SAS en R

nom = "C:/TxMarg/sortie/t_X.csv"
t_X = read.csv2(nom)


nom = "C:/TxMarg/sortie/d_X.csv"
d_X = read.csv2(nom)

nom = "C:/TxMarg/sortie/d_X.csv"
d_X = read.csv2(nom)
min(d_X$Min)

nom = "C:/TxMarg/sortie/r_X.csv"
r_X = read.csv2(nom)
min(r_X$Min)

nom = "C:/TxMarg/sortie/result.csv"
result = read.csv2(nom)

nom = "C:/TxMarg/sortie/controle09.csv"
controle09 = read.csv2(nom)
min(r_X$Min)
names(controle09)

#  "REVNET_1000"   "X_TYPE_"       "X_FREQ_"       "t_revdisp"    
#  "t_minima"      "t_pf_condress" "t_pf_sansress" "t_af"  "t_alog"   "t_prelev"
sum(controle09$X_FREQ_)/2


plot.window(xlim=c(1,200), ylim=c(-100,100))

graph <- function(table) {
  for (var in names(table)) {
    if (substr(var,1,2)=="t_" & var != "t_af") {
      
      condition = which(table[,var] != 0)
      print(var)
      print (condition)
      print(table[condition,var])
      plot(table[condition,"REVNET_1000"],table[condition,var], type = "l")
      title(main=paste("taux marginal",substring(var,3)) )
    }
  } 
}

graph(result)



var = "t_alog"
controle09[,var]
condition = which(controle09[,var] != 0)
controle09[condition,var]
plot(controle09[condition,"REVNET_1000"],controle09[condition,var], type = "l")

get(var)