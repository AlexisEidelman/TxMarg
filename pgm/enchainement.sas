/* il faut encore travailler sur l'APA
*/


**********************
enchainement de l'initialisation; 

%let anref =2009;
%let anleg= 2011;

%let anr=%substr(&anref,3,2);
%let anr1=%substr(%eval(&anref+1),3,2);
%let anr2=%substr(%eval(&anref+2),3,2);
%let anl=%substr(&anleg,3,2);

*place de l'arborescence INES :;
%let chemin_dossier=X:\HAB-INES\INES;
%let chemin_dossier_tx_marg=X:\HAB-INES\études\Taux marginaux;
%let chemin_bases=X:\HAB-INES\Tables INES;
*place des sorties de taux marginaux;
%let chemin_tx_marg=X:\HAB-INES\études\Taux marginaux\tables;

/*imputation */
libname base0		   	"&chemin_bases.\Base &anref\base";
libname base		   	"&chemin_tx_marg.\base";
/*modele*/ 
libname modele0		   	"&chemin_bases.\Leg &anleg base &anref";
libname modele		   	"&chemin_tx_marg.\Leg &anleg";
libname tx_marg			"X:\HAB-INES\études\Taux marginaux\tables\Selection_individus";

/*imputations à déplacer */
libname RPM  	       	"&chemin_bases.\Base &anref\RPM";
libname travail	       "&chemin_bases.\Base &anref\travaillées";


/****************************************************************************************
************************  Modification des revenus de la base  **************************
****************************************************************************************/
%include  "&chemin_dossier_tx_marg.\0_selection_indiv.sas"; 
%let tx_augm=0.01;
%include  "&chemin_dossier_tx_marg.\1_augment_rev.sas";


*macros; 
%include  "&chemin_dossier.\pgm\macros.sas";
*paramètres;
%let import=non; %let tx=1;
%let dossier= &chemin_dossier.\paramètres;
%include  "&chemin_dossier.\pgm\paramètres.sas";

%include  "&chemin_dossier_tx_marg.\2_modele.sas";


/*sortie*/

*on exclut ces deux étapes de la macro sortie pour ne pas avoir de problème dans compar par exemple sur les mariés;
data modele0.basemen;
	merge 	modele0.basemen (in=a) 
			modele0.Cotis_menage(keep=ident coMALpm coFApm coACpm coCHpm coREpm coTAXpm);
	by ident;
	Cotis_patro=sum(0,coMALpm,coFApm,coACpm,coCHpm,coREpm,coTAXpm);
	drop  coMALpm coFApm coACpm coCHpm coREpm coTAXpm;
	if a;
	revbrut=revsbrut-Cotis_patro;
run;
data modele.basemen;
	merge 	modele.basemen (in=a) 
			modele.Cotis_menage(keep=ident coMALpm coFApm coACpm coCHpm coREpm coTAXpm);
	by ident;
	Cotis_patro=sum(0,coMALpm,coFApm,coACpm,coCHpm,coREpm,coTAXpm);
	drop  coMALpm coFApm coACpm coCHpm coREpm coTAXpm;
	if a;
	revbrut=revsbrut-Cotis_patro;
run;

%let sortie = X:\HAB-INES\études\Taux marginaux\sorties;
%include  "&chemin_dossier_tx_marg.\macro_sortie.sas";
%sortie_tx_marg;
