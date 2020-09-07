/**
* Name: Modelo4n
* Modelo probado en GAMA v1.81. 
* Author: ec
* Tags: 
*/


model Modelo4n

global {
    file g_ArchivoCamino <- file("../maps/IquiqueFull/LineasIquique.shp");
    file g_ArchivoManzanas <- file("../maps/IquiqueFull/ManzanasIquique.shp");
    file g_ArchivoLineaSeguridad <- file("../maps/IquiqueFull/LineaSeguridadIquique2018.shp");
    file g_ArchivoPuntosEncuentros <- file("../maps/IquiqueFull/PuntosEncuentrosIquique.shp");
    file g_ArchivoGeometriaPuntosEncuentros <- file("../maps/IquiqueFull/GeometriaPuntosEncuentrosIqq.shp");
    string NombreArchivoResultado <- "txtModelo4_";
    geometry shape <- envelope(g_ArchivoManzanas);
    graph g_GrafoCamino;
    int var1 <- 0;
    int var2 <- 0;
    int var3 <- 0;
    int cantPersonasSeguras <- 0;
    int cantPersonas <- 99193;
    int cantInicialInfectados <- 414;
    int cantInfectados80 <- int(with_precision(cantInicialInfectados * 0.8,0));
    int cantInfectados20 <- int(with_precision(cantInicialInfectados * 0.2,0));
    int cantInfectados50 <- int(with_precision(cantInicialInfectados * 0.5,0));
    int cantRecuperados <- 1623;
	int cantPersonasInfectadasEvacuacion <- 0 update: Persona count(each.estaInfectado);
    int cantPersonasNOInfectadas <- cantPersonas - cantInicialInfectados -cantRecuperados update: cantPersonas - cantPersonasInfectadasEvacuacion - cantInicialInfectados - cantRecuperados;
    
    init {
    	create Calle from: clean_network(g_ArchivoCamino.contents, 0.0, true, true) with: [direccion::string(read ("name"))];

    	g_GrafoCamino <- as_edge_graph(Calle);

    	create LineaSegura from: clean_network(g_ArchivoLineaSeguridad.contents, 0.0, true, true);

    	create PuntoSeguro from: g_ArchivoPuntosEncuentros;

		create GeometriaPuntoSeguro from: g_ArchivoGeometriaPuntosEncuentros;

    	create Manzana from: g_ArchivoManzanas with: [codigoDistrito::int(read("COD_DISTRI")), cantPersonasXmanzanas::int(read("PERSONAS")), zonaRiesgoTxt::read("ZONARIESGO")]{
    		if zonaRiesgoTxt = "SI"{
    			var1 <- var1 + cantPersonasXmanzanas;
    		}
    	}
    	
    	write var1;
    	
    	list<Manzana> ListaManzanasRiesgo <- Manzana where (each.cantPersonasXmanzanas > 0 and each.zonaRiesgoTxt = "SI");
    	
    	list<PuntoSeguro> ListaPuntosSeguros <- PuntoSeguro where true;

    	list<GeometriaPuntoSeguro> ListaGeometriaPuntoSeguro <- GeometriaPuntoSeguro where true;
    	
    	loop crearPersonasloop over: ListaManzanasRiesgo{
    		create Persona number: ListaManzanasRiesgo[var2].cantPersonasXmanzanas{
    			id <- int(self);
	        	prob <- rnd(0.2,0.9);
    			location <- any_location_in(ListaManzanasRiesgo[var2]);
    			dcInicial <- ListaManzanasRiesgo[var2].codigoDistrito;
    			geo <- ListaGeometriaPuntoSeguro;
    			//puntoEncuentro <- any_location_in(ListaGeometriaPuntoSeguro closest_to (self.location));
    		}
    		var2 <- var2 + 1;
    	}
    	
    	
    	
    	ask cantInfectados80 among Persona where (each.dcInicial = 1 or each.dcInicial = 2 or each.dcInicial = 7 or each.dcInicial = 8){
        	puedeContagiar <- true;
    	}
    	ask cantInfectados20 among Persona where (each.dcInicial = 5 or each.dcInicial = 6 or each.dcInicial = 11){
        	puedeContagiar <- true;
    	}
    	
    	ask cantRecuperados among Persona where (each.puedeContagiar = false){
    		estaRecuperado <- true;
    	}
    	
    	loop while: file_exists(NombreArchivoResultado+".txt"){
    		var3 <- var3+1;
    		NombreArchivoResultado <- NombreArchivoResultado + ""+ var3;
    	}
    	
    	//write "80: "+cantInfectados80+" 50: "+cantInfectados50+" 20: "+cantInfectados20;
    	
    	write "YA CARGO TODO";
    	
    }
    reflex parar_simulacion when: (cantPersonasSeguras = cantPersonas){
    	do pause;
    }
    
}

species Manzana {
	int codigoDistrito;
	int idManzana;
	int cantPersonasXmanzanas;
	string zonaRiesgoTxt;
	rgb color <- #gray;
	
	aspect base {
		draw shape color: color;
	}
	
}

species LineaSegura{
	rgb color <- #red;
	
    aspect geom {
    	draw shape color: color;
    }
	
}

species PuntoSeguro{
	rgb color <- #yellow;
	
    aspect geom {
    	draw circle(10) color: color;
    }
	
}

species GeometriaPuntoSeguro{
	rgb color <- #yellow;
	
    aspect geom {
    	draw shape color: color;
    }
	
}

species Calle {
	string direccion;
	rgb color <- #black;
	
    aspect geom {
    	draw shape color: color;
    }
}

species Persona skills:[moving] {
	int id;
	float prob;
	int dcInicial;
	float speed <- (0.88 + rnd(0.57)) #m/#s;
	bool puedeContagiar <- false;
	bool estaInfectado <- false;
	bool estaRecuperado <- false;
	point puntoEncuentro;
	bool meta <- false;
	bool bcamino <- false;
	list<GeometriaPuntoSeguro> geo;
    
    reflex caminocorto when: bcamino = false{
    	self.puntoEncuentro <- any_location_in(geo closest_to (self.location));
    	self.bcamino <- true;
    }
    
    reflex mover {
		do goto target: puntoEncuentro on: g_GrafoCamino;
		if(self.location = self.puntoEncuentro and meta = false){
			cantPersonasSeguras <- cantPersonasSeguras + 1;
			meta <- true;
		}
		
	}
	
	reflex infectar when: estaInfectado = false and estaRecuperado = false and puedeContagiar = false{
		float sumarProb <- 0.0;
		float sumarProb2 <- 0.0;
		float sumarProb3 <- 0.0;
		float sumarProb4 <- 0.0;
		float productosProb <- 1.0;
		float subProb <- 0.0;
		float finalProb <- 0.0;
		int var;
		string strValoresProb <- "";
		int cantPersonasRadio <- 0;
		list<Persona> ListaPersonasRadio <- Persona at_distance 1.8 #m where (each.puedeContagiar);
		
		if(ListaPersonasRadio != nil){
			cantPersonasRadio <- length(ListaPersonasRadio);
		}
		
		if(cantPersonasRadio >5){
			cantPersonasRadio <- 5;
		}
		
		if(cantPersonasRadio = 1){
			subProb <- ListaPersonasRadio[0].prob;
		}
		if(cantPersonasRadio = 2){
			loop i from: 0 to: cantPersonasRadio-1{
				sumarProb <- sumarProb + ListaPersonasRadio[i].prob;
				productosProb <- productosProb * ListaPersonasRadio[i].prob;
			}
			subProb <- sumarProb - productosProb;
		}
		if(cantPersonasRadio = 3){
			loop i from: 0 to: cantPersonasRadio-2{
				loop j from: i+1 to: cantPersonasRadio-1{
					sumarProb2 <- sumarProb2 + (ListaPersonasRadio[i].prob * ListaPersonasRadio[j].prob);
				}
			}
			loop i from: 0 to: cantPersonasRadio-1{
				sumarProb <- sumarProb + ListaPersonasRadio[i].prob;
				productosProb <- productosProb * ListaPersonasRadio[i].prob;
			}
			
			subProb <- sumarProb - sumarProb2 + productosProb;
		}
		if(cantPersonasRadio = 4){
			loop i from: 0 to: cantPersonasRadio-3{
				loop j from: i+1 to: cantPersonasRadio-2{
					loop k from: j+1 to: cantPersonasRadio-1{
						sumarProb3 <- sumarProb3 + (ListaPersonasRadio[i].prob * ListaPersonasRadio[j].prob * ListaPersonasRadio[k].prob);
					}
					
				}
			}
			loop i from: 0 to: cantPersonasRadio-2{
				loop j from: i+1 to: cantPersonasRadio-1{
					sumarProb2 <- sumarProb2 + (ListaPersonasRadio[i].prob * ListaPersonasRadio[j].prob);
				}
			}
			loop i from: 0 to: cantPersonasRadio-1{
				sumarProb <- sumarProb + ListaPersonasRadio[i].prob;
				productosProb <- productosProb * ListaPersonasRadio[i].prob;
			}

			subProb <- sumarProb - sumarProb2 + sumarProb3 - productosProb;
		}
		if(cantPersonasRadio = 5){
			loop i from: 0 to: cantPersonasRadio-4{
				loop j from: i+1 to: cantPersonasRadio-3{
					loop k from: j+1 to: cantPersonasRadio-2{
						loop l from: k+1 to: cantPersonasRadio-1{
							sumarProb4 <- sumarProb4 + (ListaPersonasRadio[i].prob * ListaPersonasRadio[j].prob * ListaPersonasRadio[k].prob* ListaPersonasRadio[l].prob);
						}
					}
				}
			}
			loop i from: 0 to: cantPersonasRadio-3{
				loop j from: i+1 to: cantPersonasRadio-2{
					loop k from: j+1 to: cantPersonasRadio-1{
						sumarProb3 <- sumarProb3 + (ListaPersonasRadio[i].prob * ListaPersonasRadio[j].prob * ListaPersonasRadio[k].prob);
					}
					
				}
			}
			loop i from: 0 to: cantPersonasRadio-2{
				loop j from: i+1 to: cantPersonasRadio-1{
					sumarProb2 <- sumarProb2 + (ListaPersonasRadio[i].prob * ListaPersonasRadio[j].prob);
				}
			}
			loop i from: 0 to: cantPersonasRadio-1{
				sumarProb <- sumarProb + ListaPersonasRadio[i].prob;
				productosProb <- productosProb * ListaPersonasRadio[i].prob;
			}

			subProb <- sumarProb - sumarProb2 + sumarProb3 - sumarProb4 + productosProb;
		}
		
		finalProb <- subProb * self.prob;
		
		if(cantPersonasRadio > 0){
			loop i from: 0 to: cantPersonasRadio-1{
				strValoresProb <- "" + strValoresProb + " " + ListaPersonasRadio[i].prob with_precision 2;
			}
			
			if(finalProb > 0.5){
				save ("Tiempo_(s) "+ string(cycle) +";" + " ID_SUSCEPTIBLE " +self.id +";" + " SUSCEPTIBLE " +self.prob with_precision 2 +";" + " Cant_Infectados "+ cantPersonasRadio +" Probs "+ strValoresProb  + ";"+ " EXPUESTO " + finalProb with_precision 2+ ";"+"ZONA_SEGURA "+ self.meta) to: NombreArchivoResultado+".txt" type: "text" rewrite: false;
				self.estaInfectado <- true;
			}else{
				save ("Tiempo_(s) "+ string(cycle) +";" + " ID_SUSCEPTIBLE " +self.id +";" + " SUSCEPTIBLE " +self.prob with_precision 2 +";" + " Cant_Infectados "+ cantPersonasRadio +" Probs "+ strValoresProb  + ";"+ " NO_EXPUESTO " + finalProb with_precision 2+ ";"+"ZONA_SEGURA "+ self.meta) to: NombreArchivoResultado+".txt" type: "text" rewrite: false;
			}
			
		}
	}
	
    aspect base {
    	draw circle(1) color: puedeContagiar ? #red : (estaInfectado ? #green : (estaRecuperado ? #yellow : #blue)) border: #black;
    }
}

experiment main_experiment type:gui{
    output {
    	display map {
        	species Manzana aspect: base;
        	species Calle aspect:geom;
        	species LineaSegura aspect:geom;
        	species PuntoSeguro aspect:geom;
        	species Persona aspect:base;
    	}
    	
    	monitor "Susceptible : S" value: cantPersonasNOInfectadas;
    	monitor "Exposed : E" value: cantPersonasInfectadasEvacuacion;
    	monitor "Infectious : I" value: cantInicialInfectados;
    	monitor "Recovered : R" value: cantRecuperados;
    	monitor "Pers. en ZS" value: cantPersonasSeguras;
    }
}